import SwiftUI

/// Представление настроек горячих клавиш
/// Поддерживает любые клавиши через CGEventTap (требует Accessibility)
struct HotkeySettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var hasAccessibility: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Accessibility Info
            if !hasAccessibility {
                SettingsCard(title: "Accessibility Required", icon: "exclamationmark.triangle.fill", color: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PushToTalk requires Accessibility permissions to capture hotkeys and insert transcribed text.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            PermissionManager.shared.requestAccessibilityPermission()
                            // Проверяем через 1 секунду
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                hasAccessibility = AXIsProcessTrusted()
                            }
                        } label: {
                            Label("Open System Settings", systemImage: "gear")
                                .font(.subheadline)
                        }
                    }
                }
            }

            // Hotkey Recorder
            SettingsCard(title: Strings.Hotkeys.hotkey, icon: "keyboard.badge.ellipsis", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    if hasAccessibility {
                        HotkeyRecorderView(hotkey: Binding(
                            get: { hotkeyManager.currentHotkey },
                            set: { newHotkey in
                                guard let hotkey = newHotkey else { return }
                                hotkeyManager.saveHotkey(hotkey)
                            }
                        ))
                    } else {
                        Text("Enable Accessibility permissions to customize hotkey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allowed keys:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• F1–F19 without modifiers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• Any key with ⌘ / ⌥ / ⌃ modifier")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Plain letter/symbol keys are not allowed (conflict with text input)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            // Active Hotkey display
            SettingsCard(title: Strings.Hotkeys.activeHotkey, icon: "keyboard.fill", color: .blue) {
                HStack {
                    Text(hotkeyManager.currentHotkey.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("CGEventTap")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.15))
                        )
                        .foregroundColor(.green)
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

            // Recommended Keys
            SettingsCard(title: "Recommended Keys", icon: "star.fill", color: .yellow) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("F13–F19: Rarely used by other apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("⌥+key: Option + any letter/number (e.g. ⌥F or ⌥`)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("⌃+key: Control + any key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Avoid: F1–F12 (system media/brightness keys)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Avoid: ⌘Q, ⌘W, ⌘Tab (system shortcuts)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}
