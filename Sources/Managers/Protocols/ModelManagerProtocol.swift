import Foundation
import Combine

/// Протокол менеджера для управления Whisper моделями
/// Абстракция для model management позволяет легко подменять реализацию и создавать моки для тестирования
public protocol ModelManagerProtocol: ObservableObject {
    // MARK: - Properties

    /// Список доступных для загрузки моделей
    var availableModels: [WhisperModel] { get }

    /// Список загруженных (локально доступных) моделей
    var downloadedModels: [String] { get }

    /// Текущая выбранная модель
    var currentModel: String { get }

    /// Идёт ли загрузка модели в данный момент
    var isDownloading: Bool { get }

    /// Прогресс загрузки (0.0 - 1.0)
    var downloadProgress: Double { get }

    /// Какая модель загружается в данный момент
    var downloadingModel: String? { get }

    /// Последняя ошибка загрузки
    var downloadError: String? { get }

    /// Список поддерживаемых моделей (tiny, base, small, medium, large)
    var supportedModels: [WhisperModel] { get }

    // MARK: - Model Management

    /// Сохранение текущей выбранной модели
    /// - Parameter model: Название модели
    func saveCurrentModel(_ model: String)

    /// Сканирование загруженных моделей
    func scanDownloadedModels()

    /// Проверка загружена ли модель
    /// - Parameter modelName: Название модели
    /// - Returns: true если модель загружена, false иначе
    func isModelDownloaded(_ modelName: String) -> Bool

    /// Проверка доступности модели
    /// - Parameter modelName: Название модели
    /// - Returns: true если модель доступна, false иначе
    func checkModelAvailability(_ modelName: String) async -> Bool

    /// Загрузка модели
    /// - Parameter modelName: Название модели для загрузки
    func downloadModel(_ modelName: String) async throws

    /// Удаление модели
    /// - Parameter modelName: Название модели для удаления
    func deleteModel(_ modelName: String) async throws
}
