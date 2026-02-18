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
                SettingsCard(title: Strings.Hotkeys.accessibilityRequired, icon: "exclamationmark.triangle.fill", color: .orange) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Strings.Hotkeys.accessibilityDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button {
                            PermissionManager.shared.requestAccessibilityPermission()
                            // Проверяем через 1 секунду
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                hasAccessibility = AXIsProcessTrusted()
                            }
                        } label: {
                            Label(Strings.Hotkeys.openSystemSettings, systemImage: "gear")
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
                        Text(Strings.Hotkeys.accessibilityDisabledHint)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Strings.Hotkeys.allowedKeys)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• " + Strings.Hotkeys.fKeysAllowed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• " + Strings.Hotkeys.modifierKeysAllowed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(Strings.Hotkeys.plainKeysNotAllowed)
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
            SettingsCard(title: Strings.Hotkeys.howToUse, icon: "questionmark.circle", color: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    InstructionRow(icon: "hand.tap", text: Strings.Hotkeys.howToUseHold)
                    InstructionRow(icon: "text.bubble", text: Strings.Hotkeys.howToUseRelease)
                    InstructionRow(icon: "character.cursor.ibeam", text: Strings.Hotkeys.howToUseInsert)
                }
            }

            // Recommended Keys
            SettingsCard(title: Strings.Hotkeys.recommendedKeys, icon: "star.fill", color: .yellow) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Strings.Hotkeys.recommendedF13F19)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Strings.Hotkeys.recommendedOption)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Strings.Hotkeys.recommendedControl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Strings.Hotkeys.avoidF1F12)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Strings.Hotkeys.avoidSystemShortcuts)
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
