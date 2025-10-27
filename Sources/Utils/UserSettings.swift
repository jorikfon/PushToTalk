import Foundation

/// Менеджер пользовательских настроек приложения
/// Использует UserDefaults для персистентного хранения
public class UserSettings {
    public static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let transcriptionPrompt = "transcriptionPrompt"
        static let useProgrammingPrompt = "useProgrammingPrompt"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let stopWords = "stopWords"
        static let maxRecordingDuration = "maxRecordingDuration"
    }

    // Встроенный промпт для программирования (русский + английский)
    private let programmingPrompt = """
Транскрипция содержит программирование на русском и английском.
Технические термины: function, const, let, var, import, export, async, await, \
array, object, string, integer, boolean, class, interface, type, null, undefined, \
return, if, else, for, while, try, catch, API, JSON, HTTP, REST, database, query, \
Swift, Python, JavaScript, TypeScript, React, Node.js, Git, Docker, Kubernetes, \
Metal, GPU, CPU, memory, cache, buffer, thread, async, sync, framework, library.
"""

    private init() {
        LogManager.app.info("UserSettings: Инициализация")
    }

    // MARK: - Language Settings

    /// Язык транскрипции
    /// "ru" - русский (поддерживает английские слова)
    /// "en" - английский
    /// nil - автоопределение (может быть нестабильно)
    public var transcriptionLanguage: String? {
        get {
            // По умолчанию русский (лучше работает с mixed content)
            return defaults.string(forKey: Keys.transcriptionLanguage) ?? "ru"
        }
        set {
            defaults.set(newValue, forKey: Keys.transcriptionLanguage)
            LogManager.app.info("Язык транскрипции: \(newValue ?? "auto")")
        }
    }

    // MARK: - Transcription Prompt

    /// Использовать встроенный промпт для программирования
    public var useProgrammingPrompt: Bool {
        get {
            // По умолчанию включён
            return defaults.object(forKey: Keys.useProgrammingPrompt) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Keys.useProgrammingPrompt)
            LogManager.app.info("Programming prompt: \(newValue ? "включён" : "выключен")")
        }
    }

    /// Пользовательский промпт (дополнительный к встроенному)
    /// Пример: "OpenAI, WhisperKit, SwiftUI, Metal, GPU acceleration"
    public var customPrompt: String {
        get {
            return defaults.string(forKey: Keys.transcriptionPrompt) ?? ""
        }
        set {
            defaults.set(newValue, forKey: Keys.transcriptionPrompt)
            LogManager.app.info("Пользовательский промпт обновлён: \"\(newValue.isEmpty ? "(пусто)" : newValue)\"")
        }
    }

    /// Возвращает финальный промпт для использования
    /// Комбинирует встроенный промпт (если включён) и пользовательский
    public var effectivePrompt: String {
        var parts: [String] = []

        if useProgrammingPrompt {
            parts.append(programmingPrompt)
        }

        if !customPrompt.isEmpty {
            parts.append(customPrompt)
        }

        return parts.joined(separator: "\n")
    }

    /// Проверяет, установлен ли хоть какой-то промпт
    public var hasPrompt: Bool {
        return useProgrammingPrompt || !customPrompt.isEmpty
    }

    // MARK: - Recording Duration Settings

    /// Максимальная длительность записи в секундах (по умолчанию 60 секунд = 1 минута)
    public var maxRecordingDuration: TimeInterval {
        get {
            let saved = defaults.double(forKey: Keys.maxRecordingDuration)
            return saved > 0 ? saved : 60.0  // По умолчанию 60 секунд
        }
        set {
            defaults.set(newValue, forKey: Keys.maxRecordingDuration)
            LogManager.app.info("Максимальная длительность записи: \(Int(newValue))с")
        }
    }

    // MARK: - Stop Words Settings

    /// Список стоп-слов (по умолчанию только "отмена")
    public var stopWords: [String] {
        get {
            if let saved = defaults.array(forKey: Keys.stopWords) as? [String] {
                return saved
            }
            // По умолчанию только "отмена"
            return ["отмена"]
        }
        set {
            defaults.set(newValue, forKey: Keys.stopWords)
            LogManager.app.info("Стоп-слова обновлены: \(newValue.joined(separator: ", "))")
        }
    }

    /// Добавить стоп-слово
    public func addStopWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }

        var current = stopWords
        if !current.contains(trimmed) {
            current.append(trimmed)
            stopWords = current
        }
    }

    /// Удалить стоп-слово
    public func removeStopWord(_ word: String) {
        var current = stopWords
        current.removeAll { $0.lowercased() == word.lowercased() }
        stopWords = current
    }

    /// Проверить, содержит ли текст стоп-слово
    public func containsStopWord(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        return stopWords.contains { lowercasedText.contains($0.lowercased()) }
    }

    /// Очистить все настройки
    public func reset() {
        customPrompt = ""
        useProgrammingPrompt = true
        stopWords = ["отмена"]
        maxRecordingDuration = 60.0
        LogManager.app.info("Настройки сброшены")
    }
}
