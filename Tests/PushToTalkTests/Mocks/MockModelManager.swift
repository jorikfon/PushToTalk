import Foundation
import Combine
@testable import PushToTalkCore

/// Mock реализация ModelManagerProtocol для тестирования
/// Позволяет симулировать загрузку/удаление моделей и контролировать состояние
public final class MockModelManager: ModelManagerProtocol, ObservableObject {

    // MARK: - ModelManagerProtocol Properties

    @Published public var availableModels: [WhisperModel] = [
        WhisperModel(name: "tiny", displayName: "Tiny", size: "75MB", speed: "fast", accuracy: "low"),
        WhisperModel(name: "base", displayName: "Base", size: "142MB", speed: "medium", accuracy: "good"),
        WhisperModel(name: "small", displayName: "Small", size: "466MB", speed: "medium", accuracy: "high"),
        WhisperModel(name: "medium", displayName: "Medium", size: "1.5GB", speed: "slow", accuracy: "very high")
    ]

    @Published public var downloadedModels: [String] = ["base"]
    @Published public var currentModel: String = "base"
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadingModel: String? = nil
    @Published public var downloadError: String? = nil

    public var supportedModels: [WhisperModel] {
        return availableModels
    }

    // MARK: - Test Configuration

    /// Должен ли mock выбрасывать ошибку при загрузке
    public var shouldThrowOnDownload = false

    /// Должен ли mock выбрасывать ошибку при удалении
    public var shouldThrowOnDelete = false

    /// Симулированная задержка загрузки (в секундах)
    public var downloadDelay: TimeInterval = 0.0

    /// Симулированная задержка удаления (в секундах)
    public var deleteDelay: TimeInterval = 0.0

    /// Пользовательское сообщение об ошибке
    public var customErrorMessage: String?

    // MARK: - Call Tracking

    public var saveCurrentModelCalled = false
    public var scanDownloadedModelsCalled = false
    public var downloadModelCalled = false
    public var deleteModelCalled = false
    public var lastSavedModel: String?
    public var lastDownloadedModel: String?
    public var lastDeletedModel: String?
    public var downloadModelCallCount = 0
    public var deleteModelCallCount = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - ModelManagerProtocol Methods

    public func saveCurrentModel(_ model: String) {
        saveCurrentModelCalled = true
        lastSavedModel = model
        currentModel = model
    }

    public func scanDownloadedModels() {
        scanDownloadedModelsCalled = true
    }

    public func isModelDownloaded(_ modelName: String) -> Bool {
        return downloadedModels.contains(modelName)
    }

    public func checkModelAvailability(_ modelName: String) async -> Bool {
        return availableModels.contains { $0.name == modelName }
    }

    public func downloadModel(_ modelName: String) async throws {
        downloadModelCalled = true
        downloadModelCallCount += 1
        lastDownloadedModel = modelName

        if shouldThrowOnDownload {
            let errorMsg = customErrorMessage ?? "Mock download error"
            throw NSError(domain: "MockModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        // Simulate download process
        await MainActor.run {
            isDownloading = true
            downloadingModel = modelName
            downloadProgress = 0.0
        }

        // Simulate download delay
        if downloadDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(downloadDelay * 1_000_000_000))
        }

        // Simulate progress updates
        for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
            await MainActor.run {
                self.downloadProgress = progress
            }
            if downloadDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(downloadDelay * 0.25 * 1_000_000_000))
            }
        }

        // Complete download
        await MainActor.run {
            self.downloadProgress = 1.0
            self.isDownloading = false
            self.downloadingModel = nil

            if !self.downloadedModels.contains(modelName) {
                self.downloadedModels.append(modelName)
            }
        }
    }

    public func deleteModel(_ modelName: String) async throws {
        deleteModelCalled = true
        deleteModelCallCount += 1
        lastDeletedModel = modelName

        if shouldThrowOnDelete {
            let errorMsg = customErrorMessage ?? "Mock delete error"
            throw NSError(domain: "MockModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }

        // Simulate delete delay
        if deleteDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(deleteDelay * 1_000_000_000))
        }

        // Remove model from downloaded list
        await MainActor.run {
            self.downloadedModels.removeAll { $0 == modelName }
        }
    }

    // MARK: - Helper Methods

    /// Сбрасывает все флаги трекинга вызовов
    public func reset() {
        saveCurrentModelCalled = false
        scanDownloadedModelsCalled = false
        downloadModelCalled = false
        deleteModelCalled = false
        lastSavedModel = nil
        lastDownloadedModel = nil
        lastDeletedModel = nil
        downloadModelCallCount = 0
        deleteModelCallCount = 0
        downloadError = nil
        isDownloading = false
        downloadProgress = 0.0
        downloadingModel = nil
    }

    /// Добавляет модель в список загруженных
    public func addDownloadedModel(_ modelName: String) {
        if !downloadedModels.contains(modelName) {
            downloadedModels.append(modelName)
        }
    }

    /// Удаляет модель из списка загруженных
    public func removeDownloadedModel(_ modelName: String) {
        downloadedModels.removeAll { $0 == modelName }
    }
}
