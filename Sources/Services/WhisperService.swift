import Foundation
import WhisperKit
import Metal

/// Сервис для транскрипции аудио через WhisperKit
/// Поддерживает модели: tiny, base, small
public class WhisperService {
    private var whisperKit: WhisperKit?
    private let modelSize: String

    // Prompt для специальных терминов и контекста
    public var promptText: String? = nil

    // Performance metrics
    public private(set) var lastTranscriptionTime: TimeInterval = 0
    public private(set) var averageRTF: Double = 0  // Real-Time Factor
    private var transcriptionCount: Int = 0
    private var totalRTF: Double = 0

    public init(modelSize: String = "small") {
        self.modelSize = modelSize
        LogManager.transcription.info("Инициализация WhisperService с моделью \(modelSize)")
    }

    /// Загрузка модели Whisper
    public func loadModel() async throws {
        LogManager.transcription.begin("Загрузка модели", details: modelSize)

        do {
            // Инициализация WhisperKit с указанной моделью
            // Модель будет загружена автоматически с Hugging Face
            // WhisperKit автоматически использует Metal GPU acceleration через MLX
            whisperKit = try await WhisperKit(
                model: modelSize,
                verbose: true,
                logLevel: .debug
            )

            LogManager.transcription.success("Модель загружена", details: modelSize)

            // Проверка Metal acceleration
            verifyMetalAcceleration()
        } catch {
            LogManager.transcription.failure("Загрузка модели", error: error)
            throw WhisperError.modelLoadFailed(error)
        }
    }

    /// Проверка использования Metal GPU acceleration
    private func verifyMetalAcceleration() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            LogManager.transcription.error("Metal GPU не доступен")
            return
        }

        let memoryGB = device.recommendedMaxWorkingSetSize / 1024 / 1024 / 1024
        let isAppleSilicon = device.supportsFamily(.apple7)
        LogManager.transcription.info("Metal GPU: \(device.name), \(memoryGB)GB, Apple Silicon: \(isAppleSilicon ? "yes" : "no")")
        LogManager.transcription.debug("Backend: MLX (Metal optimized)")
    }

    /// Быстрая транскрипция чанка для real-time отображения (упрощенные настройки)
    /// - Parameter audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    /// - Returns: Распознанный текст
    public func transcribeChunk(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        // ОПТИМАЛЬНЫЕ настройки для СМЕШАННОЙ речи (RU+EN)
        // Auto-detect даёт лучший результат для code-switching
        let options = DecodingOptions(
            task: .transcribe,        // TRANSCRIBE, не translate!
            language: nil,            // nil = auto-detect для смешанной речи
            temperature: 0.0,         // Детерминированный вывод
            usePrefillPrompt: true,   // ✅ Контекст для технических терминов
            usePrefillCache: true,    // ✅ Кэширование контекста
            detectLanguage: true      // ✅ Автоопределение языка для каждого сегмента
        )

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        guard let firstResult = results.first else {
            return ""
        }

        return firstResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Транскрипция аудио данных с измерением производительности
    /// - Parameter audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    /// - Returns: Распознанный текст
    public func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            LogManager.transcription.failure("Транскрипция", message: "Модель не загружена")
            throw WhisperError.modelNotLoaded
        }

        let sampleCount = audioSamples.count
        let audioDuration = Double(sampleCount) / 16000.0  // 16kHz sample rate

        LogManager.transcription.begin("Транскрипция", details: "\(sampleCount) samples, \(String(format: "%.2f", audioDuration))s")

        let startTime = Date()

        do {
            // ОПТИМАЛЬНЫЕ настройки для СМЕШАННОЙ речи (RU+EN)
            // Auto-detect даёт лучший результат для code-switching
            let options = DecodingOptions(
                task: .transcribe,      // transcribe (не translate!)
                language: nil,          // nil = auto-detect для смешанной речи
                temperature: 0.0,       // Детерминированный вывод
                usePrefillPrompt: true, // Используем prefill для контекста (технические термины)
                usePrefillCache: true,  // Кэширование
                detectLanguage: true    // Автоопределение языка для каждого сегмента
            )

            // Логирование настроек
            LogManager.transcription.debug("Режим: auto-detect (смешанная речь RU+EN)")

            // TODO: Добавить токенизацию промпта когда получим доступ к tokenizer
            if let prompt = promptText, !prompt.isEmpty {
                LogManager.transcription.debug("Промпт задан, но требуется токенизация: \"\(prompt.prefix(50))...\"")
            }

            let results = try await whisperKit.transcribe(
                audioArray: audioSamples,
                decodeOptions: options
            )

            // Измеряем время транскрипции
            let transcriptionTime = Date().timeIntervalSince(startTime)
            lastTranscriptionTime = transcriptionTime

            // Вычисляем Real-Time Factor (RTF)
            // RTF = transcription_time / audio_duration
            // RTF < 1.0 = faster than real-time
            // RTF > 1.0 = slower than real-time
            let rtf = transcriptionTime / audioDuration
            transcriptionCount += 1
            totalRTF += rtf
            averageRTF = totalRTF / Double(transcriptionCount)

            // Получаем финальный текст из массива результатов
            guard let firstResult = results.first else {
                LogManager.transcription.failure("Транскрипция", message: "Пустой результат")
                return ""
            }

            let transcription = firstResult.text
            let cleanedText = transcription.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            // Логирование производительности
            let speedMultiplier = audioDuration / transcriptionTime
            LogManager.transcription.success(
                "Транскрипция завершена",
                details: "\"\(cleanedText)\" (\(String(format: "%.2f", transcriptionTime))s, RTF: \(String(format: "%.2f", rtf))x, \(String(format: "%.1f", speedMultiplier))x realtime)"
            )
            LogManager.transcription.debug("Avg RTF: \(String(format: "%.2f", self.averageRTF))x over \(self.transcriptionCount) transcriptions")

            return cleanedText
        } catch {
            LogManager.transcription.failure("Транскрипция", error: error)
            throw WhisperError.transcriptionFailed(error)
        }
    }

    /// Получить статистику производительности
    public func getPerformanceStats() -> PerformanceStats {
        return PerformanceStats(
            lastTranscriptionTime: lastTranscriptionTime,
            averageRTF: averageRTF,
            transcriptionCount: transcriptionCount,
            modelSize: modelSize
        )
    }

    /// Сбросить статистику производительности
    public func resetPerformanceStats() {
        lastTranscriptionTime = 0
        averageRTF = 0
        transcriptionCount = 0
        totalRTF = 0
        LogManager.transcription.info("Статистика производительности сброшена")
    }

    /// Проверка готовности модели
    public var isReady: Bool {
        return whisperKit != nil
    }

    deinit {
        LogManager.transcription.info("WhisperService деинициализирован")
    }
}

/// Ошибки WhisperService
enum WhisperError: Error {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFormat

    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "Модель Whisper не загружена"
        case .modelLoadFailed(let error):
            return "Не удалось загрузить модель: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Ошибка транскрипции: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Неверный формат аудио данных"
        }
    }
}

/// Статистика производительности транскрипции
public struct PerformanceStats {
    public let lastTranscriptionTime: TimeInterval
    public let averageRTF: Double
    public let transcriptionCount: Int
    public let modelSize: String

    public var description: String {
        """
        Performance Statistics:
        - Model: \(modelSize)
        - Transcriptions: \(transcriptionCount)
        - Last Time: \(String(format: "%.2f", lastTranscriptionTime))s
        - Average RTF: \(String(format: "%.2f", averageRTF))x
        - Status: \(averageRTF < 1.0 ? "✓ Faster than realtime" : "⚠️ Slower than realtime")
        """
    }
}
