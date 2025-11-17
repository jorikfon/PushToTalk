import SwiftUI

/// Представление настроек горячих клавиш
struct HotkeySettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var selectedMode: HotkeySource
    @State private var customHotkey: Hotkey?
    @State private var hasAccessibilityPermission: Bool = false
    @State private var showAccessibilityAlert: Bool = false

    init(hotkeyManager: HotkeyManager) {
        self.hotkeyManager = hotkeyManager
        // Инициализируем selectedMode на основе текущей горячей клавиши
        _selectedMode = State(initialValue: hotkeyManager.currentHotkey.source)
        _customHotkey = State(initialValue: hotkeyManager.loadHotkey(for: .custom))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Mode Picker
            SettingsCard(title: "Hotkey Mode", icon: "switch.2", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose hotkey mode:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Mode", selection: $selectedMode) {
                        Text("Preset F-Keys").tag(HotkeySource.preset)
                        Text("Custom Hotkey").tag(HotkeySource.custom)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMode) { newMode in
                        handleModeChange(newMode)
                    }

                    // Режим-специфичная информация
                    if selectedMode == .preset {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("F13-F19 do not require Accessibility permission")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.blue)
                            Text("Custom hotkeys require Accessibility permission")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            // Conditional content based on selected mode
            if selectedMode == .preset {
                // F-Key Selector (Preset Mode)
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
                                        modifiers: [],
                                        source: .preset
                                    )
                                    hotkeyManager.savePresetHotkey(newHotkey)
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
                    }
                }
            } else {
                // Accessibility Permission Warning (if not granted)
                if !hasAccessibilityPermission {
                    SettingsCard(title: "Permission Required", icon: "exclamationmark.triangle.fill", color: .red) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Accessibility permission is required for custom hotkeys")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: {
                                showAccessibilityAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open System Settings")
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: {
                                checkAccessibilityPermission()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Recheck Permission")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .alert("Accessibility Permission Required", isPresented: $showAccessibilityAlert) {
                        Button("Open Settings") {
                            PermissionManager.shared.requestAccessibilityPermission()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text(PermissionManager.shared.showPermissionInstructions(for: .accessibility))
                    }
                }

                // Custom Hotkey Recorder (Custom Mode)
                SettingsCard(title: "Custom Hotkey", icon: "keyboard.badge.ellipsis", color: .purple) {
                    HotkeyRecorderView(hotkey: $customHotkey)
                        .onChange(of: customHotkey) { newHotkey in
                            if let hotkey = newHotkey {
                                hotkeyManager.saveCustomHotkey(hotkey)
                            }
                        }
                        .disabled(!hasAccessibilityPermission)
                        .opacity(hasAccessibilityPermission ? 1.0 : 0.5)
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
        .onAppear {
            checkAccessibilityPermission()
        }
    }

    // MARK: - Helper Methods

    /// Проверка Accessibility разрешения
    private func checkAccessibilityPermission() {
        hasAccessibilityPermission = PermissionManager.shared.checkAccessibilityPermission()
    }

    /// Обработка смены режима
    private func handleModeChange(_ newMode: HotkeySource) {
        // Загружаем сохраненную горячую клавишу для нового режима
        if let savedHotkey = hotkeyManager.loadHotkey(for: newMode) {
            // Используем сохранённую горячую клавишу для этого режима
            hotkeyManager.saveHotkey(savedHotkey)
        } else {
            // Если нет сохраненной горячей клавиши, используем значение по умолчанию
            if newMode == .preset {
                // Для preset режима используем F16
                let defaultPreset = Hotkey(
                    name: "F16",
                    keyCode: 106,
                    displayName: "F16",
                    modifiers: [],
                    source: .preset
                )
                hotkeyManager.savePresetHotkey(defaultPreset)
            } else {
                // Для custom режима пока не устанавливаем горячую клавишу
                // Пользователь должен записать её через HotkeyRecorderView
                customHotkey = nil
            }
        }

        // Обновляем customHotkey state для HotkeyRecorderView
        if newMode == .custom {
            customHotkey = hotkeyManager.loadHotkey(for: .custom)
        }
    }
}
