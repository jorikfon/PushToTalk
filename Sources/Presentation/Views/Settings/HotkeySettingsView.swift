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

                    Text("Click the field above and press your desired hotkey combination")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Hold Detection Settings
            SettingsCard(title: "Hold Detection", icon: "hand.point.up.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Require long press to activate", isOn: Binding(
                        get: { hotkeyManager.currentHotkey.requiresHold },
                        set: { isEnabled in
                            let newThreshold: TimeInterval = isEnabled ? 0.3 : 0
                            let updatedHotkey = Hotkey(
                                name: hotkeyManager.currentHotkey.name,
                                keyCode: hotkeyManager.currentHotkey.keyCode,
                                displayName: hotkeyManager.currentHotkey.displayName,
                                modifiers: hotkeyManager.currentHotkey.modifiers,
                                holdDurationThreshold: newThreshold
                            )
                            hotkeyManager.saveHotkey(updatedHotkey)
                        }
                    ))

                    if hotkeyManager.currentHotkey.requiresHold {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Hold duration: ")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1fs", hotkeyManager.currentHotkey.holdDurationThreshold))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }

                            Slider(
                                value: Binding(
                                    get: { hotkeyManager.currentHotkey.holdDurationThreshold },
                                    set: { newValue in
                                        let updatedHotkey = Hotkey(
                                            name: hotkeyManager.currentHotkey.name,
                                            keyCode: hotkeyManager.currentHotkey.keyCode,
                                            displayName: hotkeyManager.currentHotkey.displayName,
                                            modifiers: hotkeyManager.currentHotkey.modifiers,
                                            holdDurationThreshold: newValue
                                        )
                                        hotkeyManager.saveHotkey(updatedHotkey)
                                    }
                                ),
                                in: 0.3...1.0,
                                step: 0.1
                            )

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Short presses will have ~\(String(format: "%.0f", hotkeyManager.currentHotkey.holdDurationThreshold * 1000))ms delay")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("When enabled, you must hold the key for the specified duration to activate recording. Short presses will work normally (e.g., typing tilde).")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    Text("F13-F19: Function keys rarely used by apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Right Cmd/Option + key: Less likely to conflict with shortcuts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Avoid: Cmd+Q, Cmd+W, Cmd+Tab (system shortcuts)")
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
