import Foundation

/// Протокол сервиса транскрипции аудио через Whisper
/// Абстракция для WhisperKit позволяет легко подменять реализацию и создавать моки для тестирования
public protocol WhisperServiceProtocol {
    // MARK: - Properties

    /// Готова ли модель к транскрипции
    var isReady: Bool { get }

    /// Текущий размер загруженной модели
    var currentModelSize: String { get }

    /// Промпт для специальных терминов и контекста
    var promptText: String? { get set }

    /// Включить нормализацию аудио (по умолчанию включено)
    var enableNormalization: Bool { get set }

    /// Время последней транскрипции (в секундах)
    var lastTranscriptionTime: TimeInterval { get }

    /// Средний Real-Time Factor (RTF < 1.0 = быстрее реального времени)
    var averageRTF: Double { get }

    // MARK: - Model Management

    /// Загрузка модели Whisper
    /// - Throws: WhisperError если загрузка не удалась
    func loadModel() async throws

    /// Перезагрузка модели с новым размером
    /// - Parameter newModelSize: Размер новой модели (tiny, base, small, medium, large)
    /// - Throws: WhisperError если загрузка не удалась
    func reloadModel(newModelSize: String) async throws

    // MARK: - Transcription

    /// Транскрипция аудио данных
    /// - Parameters:
    ///   - audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    ///   - contextPrompt: Опциональный промпт с предыдущим контекстом для улучшения связности
    /// - Returns: Распознанный текст
    /// - Throws: WhisperError если транскрипция не удалась
    func transcribe(audioSamples: [Float], contextPrompt: String?) async throws -> String

    /// Быстрая транскрипция чанка для real-time отображения (упрощенные настройки)
    /// - Parameter audioSamples: Массив Float32 аудио сэмплов (16kHz mono)
    /// - Returns: Распознанный текст
    /// - Throws: WhisperError если транскрипция не удалась
    func transcribeChunk(audioSamples: [Float]) async throws -> String

    // MARK: - Performance

    /// Получить статистику производительности
    /// - Returns: Структура со статистикой (время, RTF, количество транскрипций)
    func getPerformanceStats() -> PerformanceStats

    /// Сбросить статистику производительности
    func resetPerformanceStats()
}

// MARK: - Default Implementation

public extension WhisperServiceProtocol {
    /// Транскрипция без контекстного промпта (по умолчанию)
    func transcribe(audioSamples: [Float]) async throws -> String {
        return try await transcribe(audioSamples: audioSamples, contextPrompt: nil)
    }
}
