import Foundation
import Combine
import AppKit

/// ViewModel для управления настройками приложения
/// Упрощенная версия для совместимости с существующим API
public final class SettingsViewModel: ObservableObject {

    // MARK: - Model Settings

    @Published public var selectedModelSize: String
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadingModel: String?
    @Published public var downloadError: String?

    // MARK: - Private Properties

    private let modelManager: any ModelManagerProtocol
    private let whisperService: any WhisperServiceProtocol
    private let userSettings: UserSettings

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public init(
        modelManager: any ModelManagerProtocol,
        whisperService: any WhisperServiceProtocol,
        userSettings: UserSettings
    ) {
        self.modelManager = modelManager
        self.whisperService = whisperService
        self.userSettings = userSettings

        // Initialize model settings
        self.selectedModelSize = modelManager.currentModel
    }

    // MARK: - Model Management

    /// Загружает модель
    public func downloadModel(_ modelName: String) async throws {
        do {
            try await modelManager.downloadModel(modelName)
        } catch {
            await MainActor.run {
                self.downloadError = error.localizedDescription
            }
            throw error
        }
    }

    /// Удаляет модель
    public func deleteModel(_ modelName: String) async throws {
        do {
            try await modelManager.deleteModel(modelName)
        } catch {
            await MainActor.run {
                self.downloadError = error.localizedDescription
            }
            throw error
        }
    }

    /// Применяет выбранную модель
    public func applyModelSelection() async throws {
        guard selectedModelSize != modelManager.currentModel else { return }

        modelManager.saveCurrentModel(selectedModelSize)

        if whisperService.isReady {
            try await whisperService.reloadModel(newModelSize: selectedModelSize)
        }
    }
}
