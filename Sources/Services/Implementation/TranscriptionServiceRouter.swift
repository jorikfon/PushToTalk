import Foundation

/// Стабильная обёртка над активным движком транскрипции (WhisperKit или Parakeet).
///
/// Координаторы получают один экземпляр при старте, поэтому смена типа движка
/// (whisper-модель ↔ parakeet-v3) выполняется внутри: `reloadModel` пересоздаёт
/// внутренний сервис, не меняя ссылку, которую держат потребители.
public final class TranscriptionServiceRouter: WhisperServiceProtocol {

    // MARK: - Dependencies

    private let downloadBase: URL
    private let vocabularyManager: VocabularyManagerProtocol
    private let userSettings: UserSettings

    // MARK: - State

    private var engine: WhisperServiceProtocol

    public init(
        downloadBase: URL = AppConstants.modelStorageDirectory,
        vocabularyManager: VocabularyManagerProtocol,
        userSettings: UserSettings
    ) {
        self.downloadBase = downloadBase
        self.vocabularyManager = vocabularyManager
        self.userSettings = userSettings

        let savedModel = UserDefaults.standard.string(
            forKey: AppConstants.UserDefaultsKeys.currentWhisperModel
        ) ?? "small"
        self.engine = Self.makeEngine(
            for: savedModel,
            downloadBase: downloadBase,
            vocabularyManager: vocabularyManager,
            userSettings: userSettings
        )
    }

    /// Фабрика движка по имени модели из настроек
    private static func makeEngine(
        for modelName: String,
        downloadBase: URL,
        vocabularyManager: VocabularyManagerProtocol,
        userSettings: UserSettings
    ) -> WhisperServiceProtocol {
        if AppConstants.CustomModels.isParakeet(modelName) {
            return ParakeetService(
                vocabularyManager: vocabularyManager,
                userSettings: userSettings
            )
        }
        return WhisperService(
            modelSize: modelName,
            downloadBase: downloadBase,
            vocabularyManager: vocabularyManager,
            userSettings: userSettings
        )
    }

    // MARK: - WhisperServiceProtocol

    public var isReady: Bool { engine.isReady }

    public var currentModelSize: String { engine.currentModelSize }

    public var promptText: String? {
        get { engine.promptText }
        set { engine.promptText = newValue }
    }

    public var enableNormalization: Bool {
        get { engine.enableNormalization }
        set { engine.enableNormalization = newValue }
    }

    public var lastTranscriptionTime: TimeInterval { engine.lastTranscriptionTime }

    public var averageRTF: Double { engine.averageRTF }

    public var accelerationSummary: String { engine.accelerationSummary }

    public func loadModel() async throws {
        try await engine.loadModel()
    }

    /// Переключение модели. При смене типа движка (whisper ↔ parakeet)
    /// создаёт новый сервис и прогревает его до подмены.
    public func reloadModel(newModelSize: String) async throws {
        guard newModelSize != engine.currentModelSize else { return }

        var newEngine = Self.makeEngine(
            for: newModelSize,
            downloadBase: downloadBase,
            vocabularyManager: vocabularyManager,
            userSettings: userSettings
        )
        // Переносим настройки, которые живут на уровне сервиса
        newEngine.promptText = engine.promptText
        newEngine.enableNormalization = engine.enableNormalization

        LogManager.transcription.begin(
            "Смена движка", details: "\(engine.currentModelSize) → \(newModelSize)"
        )
        try await newEngine.loadModel()
        engine = newEngine
        LogManager.transcription.success("Движок переключён", details: newModelSize)
    }

    public func transcribe(audioSamples: [Float], contextPrompt: String?) async throws -> String {
        try await engine.transcribe(audioSamples: audioSamples, contextPrompt: contextPrompt)
    }

    public func transcribeChunk(audioSamples: [Float]) async throws -> String {
        try await engine.transcribeChunk(audioSamples: audioSamples)
    }

    public func getPerformanceStats() -> PerformanceStats {
        return engine.getPerformanceStats()
    }

    public func resetPerformanceStats() {
        engine.resetPerformanceStats()
    }
}
