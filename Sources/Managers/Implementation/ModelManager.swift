//
//  ModelManager.swift
//  PushToTalk
//
//  Менеджер для управления Whisper моделями
//  Поддерживает загрузку, удаление и проверку доступных моделей
//

import Foundation
import WhisperKit

public class ModelManager: ModelManagerProtocol, ObservableObject {

    // MARK: - Backwards Compatibility (deprecated)

    /// ⚠️ DEPRECATED: Используйте ServiceContainer.shared.modelManager
    /// Временная совместимость для существующего кода
    @available(*, deprecated, message: "Use ServiceContainer.shared.modelManager instead")
    public static var shared: ModelManager {
        return ServiceContainer.shared.modelManager as! ModelManager
    }

    // MARK: - Published Properties (Protocol)

    @Published public var availableModels: [WhisperModel] = []
    @Published public var downloadedModels: [String] = []
    @Published public var currentModel: String = "small"
    @Published public var isDownloading: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadingModel: String? = nil
    @Published public var downloadError: String? = nil

    // MARK: - Constants

    /// Поддерживаемые модели Whisper (отсортированы по размеру)
    public let supportedModels: [WhisperModel] = [
        WhisperModel(name: "tiny", displayName: "Tiny", size: "~40 MB", speed: "Very Fast", accuracy: "Basic"),
        WhisperModel(name: "base", displayName: "Base", size: "~75 MB", speed: "Very Fast", accuracy: "Fair"),
        WhisperModel(name: "small", displayName: "Small", size: "~250 MB", speed: "Fast", accuracy: "Good"),
        WhisperModel(name: "medium", displayName: "Medium", size: "~770 MB", speed: "Medium", accuracy: "Better"),
        WhisperModel(name: "large-v2", displayName: "Large V2", size: "~3 GB", speed: "Slower", accuracy: "Excellent"),
        WhisperModel(name: "large-v3", displayName: "Large V3", size: "~3 GB", speed: "Slower", accuracy: "Best")
    ]

    // MARK: - Private Properties

    private let modelDirectory: URL
    private let userDefaultsKey = "currentWhisperModel"

    // MARK: - Initialization

    public init() {
        // Получаем директорию для хранения моделей
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        modelDirectory = cacheDir.appendingPathComponent("whisperkit_models", isDirectory: true)

        // Создаём директорию если не существует
        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        LogManager.app.info("ModelManager: Инициализация")
        LogManager.app.info("ModelManager: Директория моделей: \(self.modelDirectory.path)")

        // Загружаем текущую модель из настроек
        loadCurrentModel()

        // Сканируем доступные модели
        scanDownloadedModels()
    }

    // MARK: - Protocol Methods

    /// Сохранение текущей модели в UserDefaults
    public func saveCurrentModel(_ model: String) {
        currentModel = model
        UserDefaults.standard.set(model, forKey: userDefaultsKey)
        LogManager.app.info("ModelManager: Текущая модель изменена на \(model)")
    }

    /// Сканирование загруженных моделей
    public func scanDownloadedModels() {
        LogManager.app.info("ModelManager: Сканирование загруженных моделей...")

        Task {
            var foundModels: [String] = []

            // Проверяем каждую поддерживаемую модель
            for model in supportedModels {
                let isAvailable = await checkModelAvailability(model.name)
                if isAvailable {
                    foundModels.append(model.name)
                    LogManager.app.info("ModelManager: Модель \(model.name) доступна")
                }
            }

            await MainActor.run {
                self.downloadedModels = foundModels
                LogManager.app.info("ModelManager: Найдено моделей: \(foundModels.count) - \(foundModels)")
            }
        }
    }

    /// Проверка загружена ли модель
    public func isModelDownloaded(_ modelName: String) -> Bool {
        return downloadedModels.contains(modelName)
    }

    /// Проверка доступности модели через WhisperKit
    public func checkModelAvailability(_ modelName: String) async -> Bool {
        do {
            let _ = try await WhisperKit(
                model: modelName,
                verbose: false,
                logLevel: .none,
                prewarm: false
            )
            return true
        } catch {
            return false
        }
    }

    /// Загрузка модели
    public func downloadModel(_ modelName: String) async throws {
        await MainActor.run {
            isDownloading = true
            downloadingModel = modelName
            downloadProgress = 0.0
            downloadError = nil
        }

        print("ModelManager: Начало загрузки модели \(modelName)...")

        do {
            // Имитируем прогресс (WhisperKit не предоставляет реальный прогресс)
            let progressTask = Task {
                for i in 1...5 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        self.downloadProgress = Double(i) * 0.15
                    }
                }
            }

            // WhisperKit автоматически загружает модель при инициализации
            print("ModelManager: Инициализация WhisperKit для загрузки \(modelName)...")
            let _ = try await WhisperKit(
                model: modelName,
                verbose: true,
                logLevel: .info
            )

            progressTask.cancel()

            await MainActor.run {
                isDownloading = false
                downloadingModel = nil
                downloadProgress = 1.0
            }

            scanDownloadedModels()
            print("ModelManager: ✓ Модель \(modelName) успешно загружена")
        } catch {
            await MainActor.run {
                isDownloading = false
                downloadingModel = nil
                downloadProgress = 0.0
                downloadError = "Failed to download \(modelName): \(error.localizedDescription)"
            }

            print("ModelManager: ✗ Ошибка загрузки модели: \(error)")
            throw ModelError.downloadFailed(error)
        }
    }

    /// Удаление модели
    public func deleteModel(_ modelName: String) async throws {
        print("ModelManager: Удаление модели \(modelName)...")

        await MainActor.run {
            self.downloadedModels.removeAll { $0 == modelName }
            print("ModelManager: ✓ Модель \(modelName) удалена из списка")
        }

        // Если удалили текущую модель, переключаемся на small
        if currentModel == modelName {
            saveCurrentModel("small")
        }

        // Пытаемся найти и удалить файлы на диске
        let hubCacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface/models", isDirectory: true)

        let possiblePaths = [
            hubCacheDir.appendingPathComponent("openai_whisper-\(modelName)", isDirectory: true),
            hubCacheDir.appendingPathComponent("whisper-\(modelName)", isDirectory: true),
            modelDirectory.appendingPathComponent(modelName, isDirectory: true)
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.removeItem(at: path)
                print("ModelManager: Удалена директория: \(path.path)")
            }
        }

        print("ModelManager: ✓ Модель \(modelName) успешно удалена")
    }

    // MARK: - Private Methods

    /// Загрузка текущей модели из UserDefaults
    private func loadCurrentModel() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
            currentModel = saved
        }
    }

    // MARK: - Helper Methods

    /// Получение размера модели на диске
    public func getModelSize(_ modelName: String) -> String {
        if let modelInfo = getModelInfo(modelName) {
            let status = isModelDownloaded(modelName) ? " ✓" : ""
            return modelInfo.size + status
        }
        return "Unknown"
    }

    /// Получение информации о модели
    public func getModelInfo(_ modelName: String) -> WhisperModel? {
        return supportedModels.first { $0.name == modelName }
    }
}

// MARK: - WhisperModel

/// Структура для представления модели Whisper
public struct WhisperModel: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let displayName: String
    public let size: String
    public let speed: String
    public let accuracy: String

    public var description: String {
        return "\(displayName) - \(size) - Speed: \(speed), Accuracy: \(accuracy)"
    }
}

// MARK: - ModelError

/// Ошибки ModelManager
public enum ModelError: Error {
    case downloadFailed(Error)
    case modelNotFound
    case deleteFailed(Error)

    public var localizedDescription: String {
        switch self {
        case .downloadFailed(let error):
            return "Failed to download model: \(error.localizedDescription)"
        case .modelNotFound:
            return "Model not found"
        case .deleteFailed(let error):
            return "Failed to delete model: \(error.localizedDescription)"
        }
    }
}
