import SwiftUI
import Carbon
import AppKit

/// View для записи произвольной комбинации клавиш
/// Пользователь кликает в поле и нажимает желаемую комбинацию
public struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey?
    @State private var isRecording: Bool = false
    @State private var recordedKeyCombo: String = "Click to record..."
    @State private var eventMonitor: Any?

    public init(hotkey: Binding<Hotkey?>) {
        self._hotkey = hotkey
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Press any key combination:")
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

            Text("Tip: Press Esc to cancel recording")
                .font(.caption2)
                .foregroundColor(.secondary)
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

        // Создаём локальный event monitor для перехвата клавиш
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            self.handleKeyEvent(event)
            // Возвращаем nil чтобы не пропускать event дальше
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Escape отменяет запись
        if event.keyCode == 53 { // Escape
            stopRecording()
            recordedKeyCombo = hotkey?.displayName ?? "Click to record..."
            return
        }

        var modifiers: [String] = []
        var keyName = ""

        // Обрабатываем modifier flags
        let modifierFlags = event.modifierFlags

        if modifierFlags.contains(.control) {
            modifiers.append("⌃")
        }
        if modifierFlags.contains(.option) {
            modifiers.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            modifiers.append("⇧")
        }
        if modifierFlags.contains(.command) {
            modifiers.append("⌘")
        }

        // Обрабатываем основную клавишу
        let keyCode = event.keyCode

        // Функциональные клавиши (F1-F19)
        if let functionKey = getFunctionKeyName(keyCode) {
            keyName = functionKey
        }
        // Буквы и цифры
        else if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            keyName = characters.uppercased()
        }
        // Специальные клавиши
        else if let specialKey = getSpecialKeyName(keyCode) {
            keyName = specialKey
        }

        // Формируем display name
        var displayName = modifiers.joined() + (keyName.isEmpty ? "" : keyName)

        // Если только modifiers (например, Control + Command без основной клавиши)
        if keyName.isEmpty && !modifiers.isEmpty {
            displayName = modifiers.joined() + " (incomplete)"
            recordedKeyCombo = displayName
            return
        }

        // Если нет основной клавиши - игнорируем
        if keyName.isEmpty {
            return
        }

        // Создаём hotkey
        let newHotkey = Hotkey(
            name: "\(modifiers.joined())\(keyName)",
            keyCode: keyCode,
            displayName: displayName
        )

        // Сохраняем
        hotkey = newHotkey
        recordedKeyCombo = displayName

        // Останавливаем запись
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            stopRecording()
        }
    }

    /// Получить название функциональной клавиши
    private func getFunctionKeyName(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"
        default: return nil
        }
    }

    /// Получить название специальной клавиши
    private func getSpecialKeyName(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 117: return "Forward Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 71: return "Clear"
        default: return nil
        }
    }
}

/// Preview provider
struct HotkeyRecorderView_Previews: PreviewProvider {
    @State static var testHotkey: Hotkey? = Hotkey(name: "F16", keyCode: 106, displayName: "F16")

    static var previews: some View {
        VStack {
            HotkeyRecorderView(hotkey: $testHotkey)
                .padding()
        }
        .frame(width: 400, height: 200)
    }
}
