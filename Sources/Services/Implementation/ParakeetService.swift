import Foundation
import FluidAudio

/// Сервис транскрипции через NVIDIA Parakeet TDT 0.6B v3 (FluidAudio, CoreML/ANE).
///
/// Отличия от WhisperService:
/// - Промпты (prefill, контекст) не поддерживаются — транcдьюсер не принимает
///   промпт-условционирование. Словарная коррекция работает: это пост-обработка текста.
/// - Язык распознавания модель определяет сама; настройка языка используется только
///   как подсказка для фильтрации токенов по письменности (Cyrillic/Latin).
public class ParakeetService: WhisperServiceProtocol {
    private let modelName: String
    private let vocabularyManager: VocabularyManagerProtocol
    private let userSettings: UserSettings
    private let audioNormalizer = AudioNormalizer(parameters: .default)

    /// AsrManager — actor, поэтому конкурентные вызовы транскрипции безопасно сериализуются
    private var asrManager: AsrManager?
    private var decoderLayers: Int = AsrModelVersion.v3.decoderLayers

    // Промпт принимается по протоколу, но игнорируется (Parakeet не использует промпты)
    public var promptText: String? = nil

    // Включить нормализацию аудио (по умолчанию включено)
    public var enableNormalization: Bool = true

    // Performance metrics
    public private(set) var lastTranscriptionTime: TimeInterval = 0
    public private(set) var averageRTF: Double = 0
    private var transcriptionCount: Int = 0
    private var totalRTF: Double = 0

    public var currentModelSize: String {
        return modelName
    }

    public var isReady: Bool {
        return asrManager != nil
    }

    public var accelerationSummary: String {
        return "Neural Engine (CoreML) · Parakeet TDT v3"
    }

    public init(
        modelName: String = AppConstants.CustomModels.parakeetName,
        vocabularyManager: VocabularyManagerProtocol,
        userSettings: UserSettings
    ) {
        self.modelName = modelName
        self.vocabularyManager = vocabularyManager
        self.userSettings = userSettings
        LogManager.transcription.info("Инициализация ParakeetService (\(modelName))")
    }

    // MARK: - Model Management

    public func loadModel() async throws {
        LogManager.transcription.begin("Загрузка модели", details: modelName)

        do {
            // Скачивает недостающие веса в Application Support/PushToTalk/Models/asr/
            // и загружает их. Повторные запуски идут из локальной папки без сети.
            let target = AppConstants.CustomModels.parakeetDownloadTarget()
            let throttle = PercentThrottle()
            let models = try await AsrModels.downloadAndLoad(
                to: target,
                version: .v3,
                progressHandler: { progress in
                    if throttle.shouldLog(progress.fractionCompleted) {
                        LogManager.transcription.info(
                            "Parakeet: загрузка/подготовка весов \(Int(progress.fractionCompleted * 100))%"
                        )
                    }
                }
            )

            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            decoderLayers = models.version.decoderLayers
            asrManager = manager

            LogManager.transcription.success("Модель загружена", details: "Parakeet TDT v3 (ANE/CoreML)")
        } catch {
            LogManager.transcription.failure("Загрузка модели", error: error)
            throw WhisperError.modelLoadFailed(error)
        }
    }

    public func reloadModel(newModelSize: String) async throws {
        guard newModelSize != modelName else {
            if asrManager == nil {
                try await loadModel()
            }
            return
        }
        // У ParakeetService одна модель; переключение на другую (в т.ч. Whisper)
        // выполняет TranscriptionServiceRouter, пересоздавая движок целиком.
        throw WhisperError.modelLoadFailed(
            ParakeetError.unsupportedModel(newModelSize)
        )
    }

    // MARK: - Transcription

    /// Быстрая транскрипция чанка для real-time отображения
    public func transcribeChunk(audioSamples: [Float]) async throws -> String {
        let text = try await transcribeSamples(audioSamples, trackPerformance: false)
        return vocabularyManager.correctTranscription(text)
    }

    /// Транскрипция аудио данных. Контекстный промпт игнорируется.
    public func transcribe(audioSamples: [Float], contextPrompt: String? = nil) async throws -> String {
        if let context = contextPrompt, !context.isEmpty {
            LogManager.transcription.debug("Контекстный промпт проигнорирован (Parakeet не поддерживает промпты)")
        }
        let text = try await transcribeSamples(audioSamples, trackPerformance: true)
        return vocabularyManager.correctTranscription(text)
    }

    private func transcribeSamples(_ audioSamples: [Float], trackPerformance: Bool) async throws -> String {
        guard let asrManager = asrManager else {
            LogManager.transcription.failure("Транскрипция", message: "Модель не загружена")
            throw WhisperError.modelNotLoaded
        }

        // Модель принимает минимум 300 мс аудио
        guard audioSamples.count >= 4800 else {
            LogManager.transcription.debug("Чанк слишком короткий (\(audioSamples.count) сэмплов), пропускаем")
            return ""
        }

        let sampleCount = audioSamples.count
        let audioDuration = Double(sampleCount) / 16000.0
        LogManager.transcription.begin("Транскрипция", details: "\(sampleCount) samples, \(String(format: "%.2f", audioDuration))s")

        // Нормализация тихого аудио — как в WhisperService
        var processedSamples = audioSamples
        if enableNormalization {
            let stats = audioNormalizer.analyze(audioSamples)
            if stats.isQuiet {
                LogManager.transcription.info("Тихое аудио обнаружено (RMS=\(stats.rms)), применяем нормализацию")
                processedSamples = audioNormalizer.normalize(audioSamples)
            }
        }

        // Подсказка письменности из настройки языка ("ru", "en", ...); языки вне
        // списка FluidAudio (ja, zh) дают nil — модель сама определит язык
        let languageHint = Language(rawValue: userSettings.transcriptionLanguage)

        var decoderState = try TdtDecoderState(decoderLayers: decoderLayers)
        let startTime = Date()

        do {
            let result = try await asrManager.transcribe(
                processedSamples,
                decoderState: &decoderState,
                language: languageHint
            )

            if trackPerformance {
                let transcriptionTime = Date().timeIntervalSince(startTime)
                lastTranscriptionTime = transcriptionTime
                if audioDuration > 0 {
                    let rtf = transcriptionTime / audioDuration
                    transcriptionCount += 1
                    totalRTF += rtf
                    averageRTF = totalRTF / Double(transcriptionCount)
                    LogManager.transcription.success(
                        "Транскрипция завершена",
                        details: "\"\(result.text.prefix(120))\" (\(String(format: "%.2f", transcriptionTime))s, RTF: \(String(format: "%.2f", rtf))x)"
                    )
                }
            } else {
                LogManager.transcription.debug("Чанк распознан: \"\(result.text.prefix(80))\"")
            }

            return result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        } catch {
            LogManager.transcription.failure("Транскрипция", error: error)
            throw WhisperError.transcriptionFailed(error)
        }
    }

    // MARK: - Performance

    public func getPerformanceStats() -> PerformanceStats {
        return PerformanceStats(
            lastTranscriptionTime: lastTranscriptionTime,
            averageRTF: averageRTF,
            transcriptionCount: transcriptionCount,
            modelSize: modelName
        )
    }

    public func resetPerformanceStats() {
        lastTranscriptionTime = 0
        averageRTF = 0
        transcriptionCount = 0
        totalRTF = 0
    }
}

/// Ошибки ParakeetService
enum ParakeetError: Error {
    case unsupportedModel(String)

    var localizedDescription: String {
        switch self {
        case .unsupportedModel(let name):
            return "ParakeetService поддерживает только модель parakeet-v3, запрошена: \(name)"
        }
    }
}

/// Дроссель для логирования прогресса загрузки (не чаще раза в 10%)
private final class PercentThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var lastStep = -1

    func shouldLog(_ fraction: Double) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let step = Int(fraction * 10)
        if step != lastStep {
            lastStep = step
            return true
        }
        return false
    }
}
