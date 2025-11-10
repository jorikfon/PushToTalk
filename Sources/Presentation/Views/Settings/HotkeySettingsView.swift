import SwiftUI

/// Представление настроек горячих клавиш
struct HotkeySettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // F-Key Selector
            SettingsCard(title: Strings.Hotkeys.hotkeySelection, icon: "keyboard.badge.ellipsis", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите функциональную клавишу:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker(Strings.Hotkeys.hotkey, selection: Binding(
                        get: { hotkeyManager.currentHotkey.keyCode },
                        set: { newKeyCode in
                            let fKeyMap: [UInt16: String] = [
                                105: "F13",
                                107: "F14",
                                113: "F15",
                                106: "F16",
                                64: "F17",
                                79: "F18",
                                80: "F19"
                            ]
                            if let name = fKeyMap[newKeyCode] {
                                let newHotkey = Hotkey(
                                    name: name,
                                    keyCode: newKeyCode,
                                    displayName: name,
                                    modifiers: []
                                )
                                hotkeyManager.saveHotkey(newHotkey)
                            }
                        }
                    )) {
                        Text("F13").tag(UInt16(105))
                        Text("F14").tag(UInt16(107))
                        Text("F15").tag(UInt16(113))
                        Text("F16 (Default)").tag(UInt16(106))
                        Text("F17").tag(UInt16(64))
                        Text("F18").tag(UInt16(79))
                        Text("F19").tag(UInt16(80))
                    }
                    .pickerStyle(.menu)

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.green)
                        Text("F13-F19 не требуют Accessibility разрешения")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Current hotkey display
            SettingsCard(title: "Active Hotkey", icon: "keyboard.fill", color: .blue) {
                HStack {
                    Text(hotkeyManager.currentHotkey.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Instructions
            SettingsCard(title: "How to Use", icon: "questionmark.circle", color: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(icon: "hand.tap", text: "Press and hold the hotkey to start recording")
                    InstructionRow(icon: "text.bubble", text: "Release the hotkey to transcribe")
                    InstructionRow(icon: "character.cursor.ibeam", text: "Text will be inserted at cursor position")
                }
            }
        }
    }
}
