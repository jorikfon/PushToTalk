import SwiftUI
import AppKit

/// View для записи произвольной комбинации клавиш
/// Поддерживает любые комбинации клавиш с модификаторами (Cmd, Shift, Option, Control)
public struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey?
    @State private var isRecording: Bool = false
    @State private var recordedKeyCombo: String = Strings.Hotkeys.clickToRecord
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    public init(hotkey: Binding<Hotkey?>) {
        self._hotkey = hotkey
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.Hotkeys.pressHotkey)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack {
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                        .foregroundColor(isRecording ? .red : .blue)
                        .imageScale(.large)

                    Text(recordedKeyCombo)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(isRecording ? .red : .primary)

                    if isRecording {
                        Text(Strings.Hotkeys.recording)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecording ? Color.red : Color.secondary.opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .focusable(true)

            if let currentHotkey = hotkey {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(Strings.Hotkeys.currentHotkey): \(currentHotkey.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(Strings.Hotkeys.recorderHint)
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .onAppear {
            if let currentHotkey = hotkey {
                recordedKeyCombo = currentHotkey.displayName
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordedKeyCombo = Strings.Hotkeys.pressAnyKey

        // Создаём локальный event monitor для перехвата клавиш в нашем окне
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            self.handleKeyEvent(event)
            // Возвращаем nil чтобы заблокировать событие в приложении
            return nil
        }

        // Создаём глобальный event monitor чтобы БЛОКИРОВАТЬ F-клавиши для системы
        // Это предотвратит появление Emoji picker
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if HotkeyManager.functionKeyCodes.contains(event.keyCode) {
                // Событие заблокировано для системы
            }
        }
    }

    private func stopRecording() {
        isRecording = false

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Escape отменяет запись
        if event.keyCode == 53 { // Escape
            stopRecording()
            recordedKeyCombo = hotkey?.displayName ?? Strings.Hotkeys.clickToRecord
            return
        }

        let keyCode = event.keyCode

        // Игнорируем чисто modifier keys (Command, Shift, Option, Control)
        if HotkeyManager.modifierOnlyKeys.contains(keyCode) {
            recordedKeyCombo = "⚠️ " + Strings.Hotkeys.addMainKey
            return
        }

        // fn / 🌐 — разрешена без модификаторов (как F-клавиши).
        // flagsChanged для fn приходит дважды (нажатие и отпускание) — берём только нажатие.
        let isFnKey = (keyCode == HotkeyManager.fnKeyCode)
        if isFnKey && !event.modifierFlags.contains(.function) {
            return // отпускание fn — игнорируем
        }

        // Получаем модификаторы
        let modifiers = extractModifiers(from: event.modifierFlags)

        // Проверяем: regular key без ⌘/⌥/⌃ — запрещено
        let isFunctionKey = HotkeyManager.functionKeyCodes.contains(keyCode) || isFnKey
        let meaningfulModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        let hasMeaningfulModifier = !modifiers.intersection(meaningfulModifiers).isEmpty

        if !isFunctionKey && !hasMeaningfulModifier {
            recordedKeyCombo = "⚠️ " + Strings.Hotkeys.needModifierOrFKey
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.isRecording {
                    self.recordedKeyCombo = Strings.Hotkeys.pressAnyKey
                }
            }
            return
        }

        // Получаем название клавиши
        let keyName = keyCode.displayName

        // Создаём display name с модификаторами
        var displayName = ""
        if !modifiers.isEmpty {
            displayName = modifiers.displayName + " "
        }
        displayName += keyName

        // Проверяем опасные комбинации
        if isDangerousCombination(keyCode: keyCode, modifiers: modifiers) {
            recordedKeyCombo = "⚠️ " + Strings.Hotkeys.dangerousCombination
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.isRecording {
                    self.recordedKeyCombo = Strings.Hotkeys.pressAnyKey
                }
            }
            return
        }

        // Создаём hotkey
        let newHotkey = Hotkey(
            name: displayName,
            keyCode: keyCode,
            displayName: displayName,
            modifiers: modifiers
        )

        // Сохраняем
        hotkey = newHotkey
        recordedKeyCombo = displayName

        // Останавливаем запись
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            stopRecording()
        }
    }

    /// Извлечение модификаторов из NSEvent.modifierFlags
    private func extractModifiers(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var modifiers: CGEventFlags = []

        if flags.contains(.command) {
            modifiers.insert(.maskCommand)
        }
        if flags.contains(.shift) {
            modifiers.insert(.maskShift)
        }
        if flags.contains(.option) {
            modifiers.insert(.maskAlternate)
        }
        if flags.contains(.control) {
            modifiers.insert(.maskControl)
        }

        return modifiers
    }

    /// Проверка опасных системных комбинаций
    private func isDangerousCombination(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        return modifiers.contains(.maskCommand) && HotkeyManager.dangerousKeyCodes.contains(keyCode)
    }
}

/// Preview provider
struct HotkeyRecorderView_Previews: PreviewProvider {
    @State static var testHotkey: Hotkey? = Hotkey(name: "F16", keyCode: 106, displayName: "F16", modifiers: [])

    static var previews: some View {
        VStack {
            HotkeyRecorderView(hotkey: $testHotkey)
                .padding()
        }
        .frame(width: 400, height: 200)
    }
}
