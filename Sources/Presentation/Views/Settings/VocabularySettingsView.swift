import SwiftUI

/// Vocabulary settings view component extracted from ModernSettingsView
/// Manages vocabulary dictionaries and custom vocabulary entries
struct VocabularySettingsView: View {
    @ObservedObject var userSettings: UserSettings

    @State private var newVocabularyName: String = ""
    @State private var newVocabularyWords: String = ""

    var body: some View {
        vocabularyView
    }

    /// Активен ли движок Parakeet (у него нет prefill-промптов, язык определяется автоматически)
    private var parakeetActive: Bool {
        userSettings.isParakeetEngineActive
    }

    // MARK: - Views

    private var vocabularyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Language Selection
            SettingsCard(title: "Язык транскрипции", icon: "globe", color: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите основной язык для распознавания речи")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Язык", selection: $userSettings.transcriptionLanguage) {
                        Text("🇷🇺 Русский (по умолчанию)").tag("ru")
                        Text("🇬🇧 English").tag("en")
                        Text("🇪🇸 Español").tag("es")
                        Text("🇫🇷 Français").tag("fr")
                        Text("🇩🇪 Deutsch").tag("de")
                        Text("🇮🇹 Italiano").tag("it")
                        Text("🇯🇵 日本語").tag("ja")
                        Text("🇨🇳 中文").tag("zh")
                    }
                    .pickerStyle(.menu)

                    if parakeetActive {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Parakeet определяет язык сам. Выбранный язык служит только подсказкой для фильтрации символов.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Predefined Dictionaries Section
            SettingsCard(title: "Специализированные словари", icon: "book.closed.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите словари для прогрева модели. Можно выбрать несколько.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if parakeetActive {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Parakeet не использует промпты: эти словари не применяются. Замены из словаря коррекций работают.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(VocabularyDictionariesManager.shared.predefinedDictionaries) { dictionary in
                        Toggle(isOn: Binding(
                            get: { userSettings.selectedDictionaryIds.contains(dictionary.id) },
                            set: { isSelected in
                                if isSelected {
                                    if !userSettings.selectedDictionaryIds.contains(dictionary.id) {
                                        userSettings.selectedDictionaryIds.append(dictionary.id)
                                    }
                                } else {
                                    userSettings.selectedDictionaryIds.removeAll { $0 == dictionary.id }
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dictionary.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(dictionary.category)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }
                                Text(dictionary.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(dictionary.terms.count) терминов")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 4)

                        if dictionary.id != VocabularyDictionariesManager.shared.predefinedDictionaries.last?.id {
                            Divider()
                        }
                    }
                }
            }

            // Custom Prefill Prompt
            SettingsCard(title: "Кастомный промпт для прогрева", icon: "text.bubble", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Опишите контекст вашей работы для улучшения распознавания")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $userSettings.customPrefillPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100, maxHeight: 150)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)

                    Text("Пример: \"Я веб-разработчик, программирую на PHP, использую распознавание речи для команд и промптов к AI моделям\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            // Old Custom Vocabularies Section (legacy)
            SettingsCard(title: "Старые словари (устаревшее)", icon: "book.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Эти словари используются для пост-обработки (коррекция)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    vocabularyListSection
                }
            }

            // Add New Vocabulary
            SettingsCard(title: Strings.Vocabulary.addNewVocabulary, icon: "plus.circle.fill", color: .blue) {
                addVocabularySection
            }

            // Vocabulary Help
            SettingsCard(title: "О словарях и прогреве модели", icon: "info.circle", color: .cyan) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔥 Прогрев модели (Prefill Prompt)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("Словари и кастомный промпт используются для \"прогрева\" модели Whisper перед транскрипцией. Это помогает модели лучше распознавать специализированные термины и контекст вашей работы.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Text("📚 Как выбрать словари?")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("Выберите словари, соответствующие вашей работе. Например, для разработки PHP выберите 'PHP Development', для работы с VoIP добавьте 'IP Telephony'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var vocabularyListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if userSettings.vocabularies.isEmpty {
                Text("Нет добавленных словарей")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(userSettings.vocabularies) { vocab in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { userSettings.enabledVocabularies.contains(vocab.id) },
                            set: { isEnabled in
                                if isEnabled {
                                    userSettings.enableVocabulary(vocab.id)
                                } else {
                                    userSettings.disableVocabulary(vocab.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vocab.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(vocab.words.count) слов")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            userSettings.removeVocabulary(vocab.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var addVocabularySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Название словаря (например: Медицина, IT, Имена)", text: $newVocabularyName)
                .textFieldStyle(.roundedBorder)

            Text("Введите слова через запятую:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $newVocabularyWords)
                .frame(height: 80)
                .font(.body)
                .border(Color.secondary.opacity(0.3), width: 1)
                .cornerRadius(4)

            HStack {
                Spacer()

                Button("Добавить словарь") {
                    addVocabulary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newVocabularyName.isEmpty || newVocabularyWords.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func addVocabulary() {
        let name = newVocabularyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordsString = newVocabularyWords.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !wordsString.isEmpty else { return }

        // Разбиваем слова по запятой и очищаем
        let words = wordsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return }

        userSettings.addVocabulary(name: name, words: words)

        // Очищаем поля
        newVocabularyName = ""
        newVocabularyWords = ""

        LogManager.app.info("Добавлен новый словарь: \(name) с \(words.count) словами")
    }
}

#Preview {
    VocabularySettingsView(userSettings: UserSettings.shared)
}
