import SwiftUI

/// Секция общих настроек приложения (стоп-слова, длительность записи)
struct GeneralSettingsView: View {
    @ObservedObject var userSettings: UserSettings
    @State private var newStopWord: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Stop Words Section
            SettingsCard(title: Strings.General.stopWordsTitle, icon: "hand.raised.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Слова, при распознавании которых транскрипция будет отменена")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    stopWordsSection
                }
            }

            // Recording Settings
            SettingsCard(title: Strings.General.recordingSettings, icon: "timer", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Максимальная длительность записи (секунды)")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        TextField("60", value: Binding(
                            get: { Int(userSettings.maxRecordingDuration) },
                            set: { userSettings.maxRecordingDuration = TimeInterval(max(10, min(300, $0))) }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text("Диапазон: 10-300 секунд. Запись остановится автоматически.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Stop Words Section

    private var stopWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Add new stop word
            HStack {
                TextField("Добавить стоп-слово...", text: $newStopWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addNewStopWord()
                    }

                Button(action: addNewStopWord) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .disabled(newStopWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Current stop words
            if userSettings.stopWords.isEmpty {
                Text("Нет стоп-слов")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(userSettings.stopWords, id: \.self) { word in
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .foregroundColor(.orange)
                                .font(.caption)

                            Text(word)
                                .font(.body)

                            Spacer()

                            Button(action: {
                                userSettings.removeStopWord(word)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func addNewStopWord() {
        let trimmed = newStopWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        userSettings.addStopWord(trimmed)
        newStopWord = ""
    }
}
