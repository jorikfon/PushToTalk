import SwiftUI
import AppKit

/// View для записи произвольной комбинации клавиш
/// Поддерживает любые комбинации клавиш с модификаторами (Cmd, Shift, Option, Control)
public struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey?
    @State private var isRecording: Bool = false
    @State private var recordedKeyCombo: String = "Click to record..."
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    public init(hotkey: Binding<Hotkey?>) {
        self._hotkey = hotkey
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Нажмите любую комбинацию клавиш:")
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
                        Text("Recording...")
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
                    Text("Current: \(currentHotkey.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Совет: ESC для отмены. Используйте модификаторы (⌘⌥⌃⇧) для более сложных комбинаций.")
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
        recordedKeyCombo = "Press any key..."

        // Создаём локальный event monitor для перехвата клавиш в нашем окне
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            self.handleKeyEvent(event)
            // Возвращаем nil чтобы заблокировать событие в приложении
            return nil
        }

        // Создаём глобальный event monitor чтобы БЛОКИРОВАТЬ F-клавиши для системы
        // Это предотвратит появление Emoji picker
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            // Если это F13-F19, просто игнорируем
            // (система не получит событие и не покажет Emoji picker)
            let fKeyCodes: Set<UInt16> = [105, 107, 113, 106, 64, 79, 80] // F13-F19
            if fKeyCodes.contains(event.keyCode) {
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
            recordedKeyCombo = hotkey?.displayName ?? "Click to record..."
            return
        }

        let keyCode = event.keyCode

        // Игнорируем чисто modifier keys (Command, Shift, Option, Control)
        let modifierOnlyKeys: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
        if modifierOnlyKeys.contains(keyCode) {
            recordedKeyCombo = "⚠️ Добавьте основную клавишу к модификатору"
            return
        }

        // Получаем модификаторы
        let modifiers = extractModifiers(from: event.modifierFlags)

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
            recordedKeyCombo = "⚠️ Системная комбинация запрещена"

            // Через секунду возвращаем старое значение
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if self.isRecording {
                    self.recordedKeyCombo = "Press any key..."
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
        // Запрещаем Cmd+Q, Cmd+W, Cmd+Tab
        let dangerousKeyCodes: Set<UInt16> = [
            12,  // Q (Cmd+Q = Quit)
            13,  // W (Cmd+W = Close window)
            48,  // Tab (Cmd+Tab = App switcher)
        ]

        if modifiers.contains(.maskCommand) && dangerousKeyCodes.contains(keyCode) {
            return true
        }

        return false
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
