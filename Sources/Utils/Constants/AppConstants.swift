import Foundation

/// Константы приложения
/// Централизованное хранение всех настроек приложения
public enum AppConstants {
    // MARK: - Application Info

    /// Bundle identifier приложения
    public static let bundleIdentifier = "com.pushtotalk.app"

    /// Имя приложения
    public static let appName = "PushToTalk"

    /// Subsystem для OSLog
    public static let logSubsystem = "com.pushtotalk.app"

    // MARK: - Recording Settings

    /// Максимальная длительность записи по умолчанию (секунды)
    public static let defaultMaxRecordingDuration: TimeInterval = 60.0

    /// Минимальная длительность записи для сохранения (секунды)
    public static let minRecordingDuration: TimeInterval = 0.5

    /// Максимальная длительность записи (секунды)
    public static let maxRecordingDurationLimit: TimeInterval = 300.0

    // MARK: - Audio Settings

    /// Аудио параметры
    public enum Audio {
        /// Частота дискретизации для Whisper (Hz)
        public static let whisperSampleRate: Int = 16000

        /// Количество каналов
        public static let audioChannels: UInt32 = 1

        /// Формат аудио
        public static let audioFormat: String = "Float32"
    }

    /// Частота дискретизации для Whisper (Hz) - deprecated
    public static let whisperSampleRate: Double = 16000.0

    /// Количество каналов - deprecated
    public static let audioChannels: UInt32 = 1

    /// Формат аудио - deprecated
    public static let audioFormat: String = "Float32"

    // MARK: - Model Settings

    /// Размер модели по умолчанию
    public static let defaultModelSize = "base"

    /// Доступные размеры моделей
    public static let availableModelSizes = ["tiny", "base", "small", "medium", "large-v3"]

    /// Язык транскрипции по умолчанию
    public static let defaultLanguage = "ru"

    /// Доступные языки
    public static let availableLanguages = ["ru", "en"]

    // MARK: - Hotkey Settings

    /// Hotkey по умолчанию
    public static let defaultHotkey = "F16"

    /// Доступные функциональные клавиши
    public static let availableFunctionKeys = ["F13", "F14", "F15", "F16", "F17", "F18", "F19"]

    /// Доступные модификаторы
    public static let availableModifiers = ["Right Command", "Right Option", "Right Control"]

    // MARK: - Stop Words

    /// Стоп-слова по умолчанию
    public static let defaultStopWords = ["отмена"]

    // MARK: - History Settings

    /// Максимальное количество записей в истории
    public static let maxHistoryEntries = 50

    /// Максимальная длина текста для отображения в истории
    public static let maxHistoryTextLength = 500

    // MARK: - Quality Enhancement

    /// Compression Ratio Threshold по умолчанию
    public static let defaultCompressionRatioThreshold: Float = 2.4

    /// Log Probability Threshold по умолчанию
    public static let defaultLogProbThreshold: Float = -1.0

    // MARK: - File Transcription

    /// Режим транскрипции файлов по умолчанию
    public static let defaultFileTranscriptionMode = "vad"

    /// VAD алгоритм по умолчанию
    public static let defaultVADAlgorithm = "spectral_telephone"

    // MARK: - Notifications

    /// Notification names
    public enum Notifications {
        public static let modelChanged = Notification.Name("ModelChanged")
        public static let hotkeyChanged = Notification.Name("HotkeyChanged")
        public static let audioDeviceChanged = Notification.Name("AudioDeviceChanged")
        public static let recordingStarted = Notification.Name("RecordingStarted")
        public static let recordingStopped = Notification.Name("RecordingStopped")
        public static let transcriptionCompleted = Notification.Name("TranscriptionCompleted")
    }

    // MARK: - UserDefaults Keys

    /// UserDefaults ключи
    public enum UserDefaultsKeys {
        public static let transcriptionPrompt = "transcriptionPrompt"
        public static let useProgrammingPrompt = "useProgrammingPrompt"
        public static let transcriptionLanguage = "transcriptionLanguage"
        public static let stopWords = "stopWords"
        public static let maxRecordingDuration = "maxRecordingDuration"
        public static let vocabularies = "vocabularies"
        public static let enabledVocabularies = "enabledVocabularies"
        public static let fileTranscriptionMode = "fileTranscriptionMode"
        public static let vadAlgorithmType = "vadAlgorithmType"
        public static let selectedDictionaryIds = "selectedDictionaryIds"
        public static let customPrefillPrompt = "customPrefillPrompt"
        public static let useQualityEnhancement = "useQualityEnhancement"
        public static let temperatureFallback = "temperatureFallback"
        public static let compressionRatioThreshold = "compressionRatioThreshold"
        public static let logProbThreshold = "logProbThreshold"
    }

    // MARK: - Performance

    /// Таймаут для загрузки модели (секунды)
    public static let modelLoadTimeout: TimeInterval = 60.0

    /// Таймаут для транскрипции (секунды)
    public static let transcriptionTimeout: TimeInterval = 120.0

    // MARK: - Prompts

    /// Встроенный промпт для программирования
    public static let programmingPrompt = """
    Транскрипция содержит программирование на русском и английском.
    Технические термины: function, const, let, var, import, export, async, await, \
    array, object, string, integer, boolean, class, interface, type, null, undefined, \
    return, if, else, for, while, try, catch, API, JSON, HTTP, REST, database, query, \
    Swift, Python, JavaScript, TypeScript, React, Node.js, Git, Docker, Kubernetes, \
    Metal, GPU, CPU, memory, cache, buffer, thread, async, sync, framework, library.
    """
}
