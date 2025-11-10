import SwiftUI

/// Представление отладочных функций
struct DebugSettingsView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MediaRemote Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text(Strings.Debug.mediaRemoteControls)
                        .font(.headline)
                    Spacer()
                }

                Text("Управление внешними медиа-плеерами (Spotify, Apple Music, YouTube)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Sending PAUSE command...")
                        MediaRemoteManager.shared.pause()
                    }) {
                        Label(Strings.Debug.pause, systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        print("DEBUG: Sending RESUME command...")
                        MediaRemoteManager.shared.resume(force: true)
                    }) {
                        Label(Strings.Debug.resume, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                Button(action: {
                    print("DEBUG: Sending TOGGLE PLAY/PAUSE command...")
                    MediaRemoteManager.shared.togglePlayPause()
                }) {
                    Label(Strings.Debug.togglePlayPause, systemImage: "playpause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(action: {
                    MediaRemoteManager.shared.getNowPlayingInfo { info in
                        if let info = info {
                            print("DEBUG: Now Playing Info:")
                            for (key, value) in info {
                                print("  \(key): \(value)")
                            }
                        } else {
                            print("DEBUG: No now playing info available")
                        }
                    }
                }) {
                    Label(Strings.Debug.getNowPlayingInfo, systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Audio Ducking Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.purple)
                        .font(.title2)
                    Text(Strings.Debug.audioDucking)
                        .font(.headline)
                    Spacer()
                }

                Text("Управление громкостью системного аудио")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Ducking audio...")
                        AudioDuckingManager.shared.duck(force: true)
                    }) {
                        Label(Strings.Debug.duck, systemImage: "speaker.wave.1")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        print("DEBUG: Unducking audio...")
                        AudioDuckingManager.shared.unduck(force: true)
                    }) {
                        Label(Strings.Debug.unduck, systemImage: "speaker.wave.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Microphone Volume Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text(Strings.Debug.microphoneVolume)
                        .font(.headline)
                    Spacer()
                }

                Text("Управление громкостью микрофона")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Boosting microphone volume...")
                        MicrophoneVolumeManager.shared.boostMicrophoneVolume()
                    }) {
                        Label(Strings.Debug.boost, systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: {
                        print("DEBUG: Restoring microphone volume...")
                        MicrophoneVolumeManager.shared.restoreMicrophoneVolume()
                    }) {
                        Label(Strings.Debug.restore, systemImage: "mic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Logs Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text(Strings.Debug.logs)
                        .font(.headline)
                    Spacer()
                }

                Text("Для просмотра логов в реальном времени откройте Terminal:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("log stream --predicate 'subsystem == \"com.pushtotalk.app\"' --level debug")
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(4)

                Button(action: {
                    let command = "log stream --predicate 'subsystem == \"com.pushtotalk.app\"' --level debug"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    print("DEBUG: Log command copied to clipboard")
                }) {
                    Label(Strings.Debug.copyCommand, systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}
