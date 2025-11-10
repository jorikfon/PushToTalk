import SwiftUI

/// Представление настроек аудио
struct AudioSettingsView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var audioDuckingManager: AudioDuckingManager
    @ObservedObject var micVolumeManager: MicrophoneVolumeManager
    @ObservedObject var userSettings: UserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Audio Device Selection
            SettingsCard(title: Strings.Audio.audioInput, icon: "mic.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выбор микрофона")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !audioDeviceManager.availableDevices.isEmpty {
                        Picker("Микрофон", selection: Binding(
                            get: {
                                if let selected = audioDeviceManager.selectedDevice {
                                    return selected
                                }
                                return audioDeviceManager.availableDevices.first!
                            },
                            set: { device in
                                audioDeviceManager.selectDevice(device)
                            }
                        )) {
                            ForEach(audioDeviceManager.availableDevices) { device in
                                Text(device.displayName).tag(device)
                            }
                        }
                        .labelsHidden()
                    } else {
                        Text("Нет доступных устройств")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    Button("Обновить список устройств") {
                        audioDeviceManager.scanAvailableDevices()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // Audio Settings
            SettingsCard(title: Strings.Audio.audioSettings, icon: "speaker.wave.3", color: .pink) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Повышать громкость микрофона при записи", isOn: Binding(
                        get: { micVolumeManager.volumeBoostEnabled },
                        set: { micVolumeManager.saveVolumeBoostEnabled($0) }
                    ))

                    Toggle("Приглушать системный звук при записи", isOn: Binding(
                        get: { audioDuckingManager.duckingEnabled },
                        set: { audioDuckingManager.saveDuckingEnabled($0) }
                    ))

                    if audioDuckingManager.duckingEnabled {
                        Toggle("Полностью выключать звук (вместо приглушения)", isOn: Binding(
                            get: { audioDuckingManager.muteOutputCompletely },
                            set: { audioDuckingManager.saveMuteOutputCompletely($0) }
                        ))
                        .padding(.leading, 20)
                    }

                    Toggle("Ставить на паузу медиа-плееры при записи", isOn: Binding(
                        get: { audioDuckingManager.pauseMediaEnabled },
                        set: { audioDuckingManager.savePauseMediaEnabled($0) }
                    ))

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text("Автоматически ставит на паузу Spotify, Apple Music, YouTube и другие плееры")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Audio Feedback Settings
            SettingsCard(title: "Звуковая индикация", icon: "waveform", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Звуки процесса распознавания", isOn: Binding(
                        get: { AudioFeedbackManager.shared.soundEnabled },
                        set: { AudioFeedbackManager.shared.soundEnabled = $0 }
                    ))

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.purple)
                            .font(.caption)

                        Text("Воспроизведение щелчков/похрустывания во время транскрипции для индикации процесса")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
