import SwiftUI

/// SwiftUI view для настроек приложения (старая версия, оставлена для совместимости)
struct SettingsView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 16) {
            // Заголовок
            Text("PushToTalk Settings")
                .font(.headline)

            Divider()

            // Выбор размера модели
            VStack(alignment: .leading, spacing: 8) {
                Text("Whisper Model:")
                    .font(.subheadline)

                Picker("", selection: $controller.modelSize) {
                    Text("Small").tag("small")
                    Text("Medium (most accurate)").tag("medium")
                }
                .pickerStyle(.segmented)
                .help("Small: быстрая, Medium: самая точная")
            }

            // Индикатор записи
            if controller.isRecording {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Recording...")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Инструкции
            VStack(alignment: .leading, spacing: 8) {
                Label("Press and hold F16 to record", systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Release F16 to transcribe", systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("Text appears at cursor", systemImage: "character.cursor.ibeam")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Кнопка выхода
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit PushToTalk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}

// MARK: - Glass Container Modifier

/// Модификатор для создания стеклянного контейнера в стиле Liquid Glass
struct GlassContainer: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                }
            )
    }
}
