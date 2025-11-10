import XCTest
import Combine
@testable import PushToTalkCore

/// Тесты для SettingsViewModel
/// Проверяет работу модели настроек с моками зависимостей
final class SettingsViewModelTests: XCTestCase {

    // MARK: - Properties

    var viewModel: SettingsViewModel!
    var mockModelManager: MockModelManager!
    var mockWhisperService: MockWhisperService!
    var cancellables: Set<AnyCancellable>!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        mockModelManager = MockModelManager()
        mockWhisperService = MockWhisperService()
        cancellables = Set<AnyCancellable>()

        viewModel = SettingsViewModel(
            modelManager: mockModelManager,
            whisperService: mockWhisperService,
            userSettings: UserSettings.shared
        )
    }

    override func tearDown() {
        viewModel = nil
        mockModelManager = nil
        mockWhisperService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_SetsCurrentModel() {
        XCTAssertEqual(viewModel.selectedModelSize, "base", "ViewModel должна инициализироваться с текущей моделью")
        XCTAssertFalse(viewModel.isDownloading, "Загрузка не должна быть активна при инициализации")
        XCTAssertEqual(viewModel.downloadProgress, 0.0, "Прогресс загрузки должен быть 0")
        XCTAssertNil(viewModel.downloadingModel, "Не должно быть загружающейся модели")
        XCTAssertNil(viewModel.downloadError, "Не должно быть ошибки загрузки")
    }

    // MARK: - Model Download Tests

    func testDownloadModel_Success() async throws {
        // Given
        let modelToDownload = "tiny"
        XCTAssertFalse(mockModelManager.isModelDownloaded(modelToDownload), "Модель не должна быть загружена")

        // When
        try await viewModel.downloadModel(modelToDownload)

        // Then
        XCTAssertTrue(mockModelManager.downloadModelCalled, "downloadModel должен быть вызван")
        XCTAssertEqual(mockModelManager.lastDownloadedModel, modelToDownload, "Должна быть загружена правильная модель")
        XCTAssertEqual(mockModelManager.downloadModelCallCount, 1, "downloadModel должен быть вызван один раз")
        XCTAssertTrue(mockModelManager.isModelDownloaded(modelToDownload), "Модель должна быть загружена")
        XCTAssertNil(viewModel.downloadError, "Не должно быть ошибки загрузки")
    }

    func testDownloadModel_Failure() async {
        // Given
        let modelToDownload = "tiny"
        mockModelManager.shouldThrowOnDownload = true
        mockModelManager.customErrorMessage = "Network error"

        // When
        do {
            try await viewModel.downloadModel(modelToDownload)
            XCTFail("downloadModel должен выбросить ошибку")
        } catch {
            // Then
            XCTAssertTrue(mockModelManager.downloadModelCalled, "downloadModel должен быть вызван")
            XCTAssertNotNil(viewModel.downloadError, "Должна быть установлена ошибка загрузки")
            XCTAssertEqual(viewModel.downloadError, "Network error", "Сообщение об ошибке должно совпадать")
            XCTAssertFalse(mockModelManager.isModelDownloaded(modelToDownload), "Модель не должна быть загружена")
        }
    }

    func testDownloadModel_ProgressTracking() async throws {
        // Given
        let modelToDownload = "small"

        // When
        try await viewModel.downloadModel(modelToDownload)

        // Then
        XCTAssertEqual(mockModelManager.downloadProgress, 1.0, "Финальный прогресс должен быть 1.0")
        XCTAssertFalse(mockModelManager.isDownloading, "Загрузка должна завершиться")
        XCTAssertTrue(mockModelManager.isModelDownloaded(modelToDownload), "Модель должна быть загружена")
    }

    func testDownloadModel_MultipleModels() async throws {
        // Given
        let models = ["tiny", "small"]

        // When
        for model in models {
            try await viewModel.downloadModel(model)
        }

        // Then
        XCTAssertEqual(mockModelManager.downloadModelCallCount, 2, "downloadModel должен быть вызван дважды")
        for model in models {
            XCTAssertTrue(mockModelManager.isModelDownloaded(model), "Модель \(model) должна быть загружена")
        }
    }

    // MARK: - Model Delete Tests

    func testDeleteModel_Success() async throws {
        // Given
        let modelToDelete = "base"
        XCTAssertTrue(mockModelManager.isModelDownloaded(modelToDelete), "Модель должна быть загружена изначально")

        // When
        try await viewModel.deleteModel(modelToDelete)

        // Then
        XCTAssertTrue(mockModelManager.deleteModelCalled, "deleteModel должен быть вызван")
        XCTAssertEqual(mockModelManager.lastDeletedModel, modelToDelete, "Должна быть удалена правильная модель")
        XCTAssertEqual(mockModelManager.deleteModelCallCount, 1, "deleteModel должен быть вызван один раз")
        XCTAssertFalse(mockModelManager.isModelDownloaded(modelToDelete), "Модель должна быть удалена")
        XCTAssertNil(viewModel.downloadError, "Не должно быть ошибки удаления")
    }

    func testDeleteModel_Failure() async {
        // Given
        let modelToDelete = "base"
        mockModelManager.shouldThrowOnDelete = true
        mockModelManager.customErrorMessage = "Permission denied"

        // When
        do {
            try await viewModel.deleteModel(modelToDelete)
            XCTFail("deleteModel должен выбросить ошибку")
        } catch {
            // Then
            XCTAssertTrue(mockModelManager.deleteModelCalled, "deleteModel должен быть вызван")
            XCTAssertNotNil(viewModel.downloadError, "Должна быть установлена ошибка удаления")
            XCTAssertEqual(viewModel.downloadError, "Permission denied", "Сообщение об ошибке должно совпадать")
            XCTAssertTrue(mockModelManager.isModelDownloaded(modelToDelete), "Модель должна остаться загруженной")
        }
    }

    func testDeleteModel_NonExistentModel() async throws {
        // Given
        let modelToDelete = "nonexistent"
        XCTAssertFalse(mockModelManager.isModelDownloaded(modelToDelete), "Модель не должна существовать")

        // When
        try await viewModel.deleteModel(modelToDelete)

        // Then
        XCTAssertTrue(mockModelManager.deleteModelCalled, "deleteModel должен быть вызван")
        XCTAssertNil(viewModel.downloadError, "Не должно быть ошибки")
    }

    // MARK: - Model Selection Tests

    func testApplyModelSelection_SameModel_NoReload() async throws {
        // Given
        let currentModel = mockModelManager.currentModel
        viewModel.selectedModelSize = currentModel

        // When
        try await viewModel.applyModelSelection()

        // Then
        XCTAssertFalse(mockModelManager.saveCurrentModelCalled, "saveCurrentModel не должен быть вызван")
        XCTAssertFalse(mockWhisperService.reloadModelCalled, "reloadModel не должен быть вызван")
    }

    func testApplyModelSelection_DifferentModel_SavesAndReloads() async throws {
        // Given
        let newModel = "small"
        viewModel.selectedModelSize = newModel
        mockWhisperService.isReady = true

        // When
        try await viewModel.applyModelSelection()

        // Then
        XCTAssertTrue(mockModelManager.saveCurrentModelCalled, "saveCurrentModel должен быть вызван")
        XCTAssertEqual(mockModelManager.lastSavedModel, newModel, "Должна быть сохранена новая модель")
        XCTAssertEqual(mockModelManager.currentModel, newModel, "Текущая модель должна обновиться")
        XCTAssertTrue(mockWhisperService.reloadModelCalled, "reloadModel должен быть вызван")
        XCTAssertEqual(mockWhisperService.lastReloadedModelSize, newModel, "Должна быть перезагружена новая модель")
    }

    func testApplyModelSelection_WhisperNotReady_SavesButDoesNotReload() async throws {
        // Given
        let newModel = "tiny"
        viewModel.selectedModelSize = newModel
        mockWhisperService.isReady = false

        // When
        try await viewModel.applyModelSelection()

        // Then
        XCTAssertTrue(mockModelManager.saveCurrentModelCalled, "saveCurrentModel должен быть вызван")
        XCTAssertEqual(mockModelManager.currentModel, newModel, "Текущая модель должна обновиться")
        XCTAssertFalse(mockWhisperService.reloadModelCalled, "reloadModel не должен быть вызван т.к. WhisperService не готов")
    }

    func testApplyModelSelection_ReloadFailure() async {
        // Given
        let newModel = "medium"
        viewModel.selectedModelSize = newModel
        mockWhisperService.isReady = true
        mockWhisperService.shouldThrowOnReload = true

        // When
        do {
            try await viewModel.applyModelSelection()
            XCTFail("applyModelSelection должен выбросить ошибку")
        } catch {
            // Then
            XCTAssertTrue(mockModelManager.saveCurrentModelCalled, "saveCurrentModel должен быть вызван")
            XCTAssertTrue(mockWhisperService.reloadModelCalled, "reloadModel должен быть вызван")
            XCTAssertEqual(mockModelManager.currentModel, newModel, "Модель должна быть сохранена несмотря на ошибку reload")
        }
    }

    // MARK: - Integration Tests

    func testFullModelChangeFlow() async throws {
        // Given
        let newModel = "tiny"
        mockWhisperService.isReady = true

        // Download new model
        try await viewModel.downloadModel(newModel)
        XCTAssertTrue(mockModelManager.isModelDownloaded(newModel), "Модель должна быть загружена")

        // Select new model
        viewModel.selectedModelSize = newModel

        // Apply selection
        try await viewModel.applyModelSelection()

        // Then
        XCTAssertEqual(mockModelManager.currentModel, newModel, "Текущая модель должна быть обновлена")
        XCTAssertTrue(mockWhisperService.reloadModelCalled, "WhisperService должен перезагрузить модель")
        XCTAssertEqual(viewModel.selectedModelSize, newModel, "selectedModelSize должен совпадать с новой моделью")
    }

    // MARK: - Performance Tests

    func testPerformance_DownloadMultipleModels() {
        mockModelManager.downloadDelay = 0.01

        measure {
            let expectation = expectation(description: "Multiple downloads")
            Task {
                for model in ["tiny", "small"] {
                    try? await viewModel.downloadModel(model)
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
}
