import Foundation
import Cocoa
import Combine
import PushToTalkCore

/// Главный координатор приложения
/// Управляет жизненным циклом приложения и координирует все подкоординаторы
///
/// Отвечает за:
/// - Инициализацию всех сервисов через ServiceContainer
/// - Создание и управление RecordingCoordinator и SettingsCoordinator
/// - Настройку menu bar и keyboard monitoring
/// - Загрузку Whisper модели
/// - Проверку разрешений
/// - Координацию между различными частями приложения
public final class AppCoordinator {
    // MARK: - Dependencies

    private let container: ServiceContainer

    // MARK: - Sub-coordinators

    private let recordingCoordinator: RecordingCoordinator
    private let settingsCoordinator: SettingsCoordinator

    // MARK: - UI Components

    private let menuBarController: MenuBarController
    private let floatingWindow: FloatingRecordingWindow

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(container: ServiceContainer = .shared) {
        self.container = container

        // Инициализация UI компонентов с DI
        self.menuBarController = MenuBarController(
            audioDeviceManager: container.audioDeviceManager,
            alertService: container.alertService
        )
        self.floatingWindow = FloatingRecordingWindow()

        // Инициализация координаторов
        self.recordingCoordinator = RecordingCoordinator(
            audioService: container.audioService,
            whisperService: container.whisperService,
            textInserter: container.textInserter,
            menuBarController: menuBarController,
            floatingWindow: floatingWindow
        )

        self.settingsCoordinator = SettingsCoordinator(
            whisperService: container.whisperService,
            modelManager: container.modelManager,
            audioDeviceManager: container.audioDeviceManager,
            vocabularyManager: container.vocabularyManager,
            hotkeyManager: container.hotkeyManager,
            keyboardMonitor: container.keyboardMonitor,
            menuBarController: menuBarController
        )
    }

    // MARK: - Public API

    /// Запуск приложения (вызывается из applicationDidFinishLaunching)
    public func start() async {
        LogManager.app.info("=== AppCoordinator: Запуск приложения ===")

        // 1. Настройка menu bar (должно быть на main thread)
        await MainActor.run {
            setupMenuBar()
        }

        // 2. Проверка разрешений
        await checkPermissions()

        // 3. Настройка уведомлений
        await setupNotifications()

        // 4. Загрузка Whisper модели
        await loadWhisperModel()

        // 5. Запуск мониторинга клавиатуры (должно быть на main thread)
        await MainActor.run {
            setupKeyboardMonitoring()
        }

        // 6. Настройка уведомлений для тестовой записи
        setupTestRecordingNotifications()

        LogManager.app.success("AppCoordinator: Инициализация завершена")
    }

    /// Остановка приложения (вызывается из applicationWillTerminate)
    public func stop() {
        LogManager.app.info("=== AppCoordinator: Остановка приложения ===")

        // Останавливаем мониторинг клавиатуры
        container.keyboardMonitor.stopMonitoring()

        // Закрываем окно настроек если открыто
        settingsCoordinator.closeSettings()

        LogManager.app.info("AppCoordinator: Cleanup завершен")
    }

    // MARK: - Private Methods - Setup

    /// Настройка menu bar
    private func setupMenuBar() {
        menuBarController.setupMenuBar()

        // Callback для открытия настроек из menu bar
        menuBarController.onSettingsRequested = { [weak self] in
            self?.settingsCoordinator.showSettings()
        }

        // Callback для смены модели из menu bar
        menuBarController.modelChangedCallback = { [weak self] newModelSize in
            guard let self = self else { return }

            Task {
                await self.handleModelChange(newModelSize: newModelSize)
            }
        }
    }

    /// Настройка мониторинга клавиатуры
    private func setupKeyboardMonitoring() {
        // Запуск мониторинга
        let started = container.keyboardMonitor.startMonitoring()
        if started {
            let hotkey = container.hotkeyManager.currentHotkey.displayName
            LogManager.app.success("Мониторинг клавиатуры запущен", details: "Hotkey: \(hotkey)")
        } else {
            LogManager.app.failure("Мониторинг клавиатуры", message: "Не удалось запустить")
            return
        }

        // Async/await обработка событий клавиатуры через AsyncStream
        Task {
            for await event in container.keyboardMonitor.hotkeyEvents {
                switch event {
                case .pressed:
                    recordingCoordinator.startRecording()
                case .released:
                    recordingCoordinator.stopRecording()
                }
            }
        }

        // Async/await обработка real-time аудио чанков через AsyncStream
        Task {
            for await chunk in container.audioService.audioChunks {
                recordingCoordinator.handleAudioChunk(chunk)
            }
        }
    }

    /// Настройка уведомлений для тестовой записи из UI (Combine Publishers)
    private func setupTestRecordingNotifications() {
        // Подписка на "StartTestRecording" через Combine Publisher
        NotificationCenter.default.publisher(for: NSNotification.Name("StartTestRecording"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recordingCoordinator.startRecording()
            }
            .store(in: &cancellables)

        // Подписка на "StopTestRecording" через Combine Publisher
        NotificationCenter.default.publisher(for: NSNotification.Name("StopTestRecording"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recordingCoordinator.stopRecording()
            }
            .store(in: &cancellables)

        LogManager.app.info("Test recording notifications настроены (Combine Publishers)")
    }

    /// Проверка всех необходимых разрешений
    private func checkPermissions() async {
        let permissionManager = container.permissionManager
        let status = await permissionManager.checkAllPermissions()

        // Установка флага разрешения микрофона в audioService
        if status.microphone {
            _ = await container.audioService.checkPermissions()
        }

        // Показ предупреждений если разрешения не предоставлены
        if !status.microphone {
            menuBarController.showError(
                permissionManager.showPermissionInstructions(for: .microphone)
            )
        }

        if !status.accessibility {
            LogManager.app.failure("Accessibility не разрешен", message: "Требуется для CGEventTap")

            // Запрос разрешения Accessibility
            permissionManager.requestAccessibilityPermission()

            menuBarController.showError(
                permissionManager.showPermissionInstructions(for: .accessibility)
            )
        }
    }

    /// Настройка системы уведомлений
    private func setupNotifications() async {
        let notificationManager = container.notificationManager

        // Настройка категорий уведомлений
        notificationManager.setupNotificationCategories()

        // Запрос разрешения на уведомления
        let granted = await notificationManager.requestPermission()

        if granted {
            LogManager.app.success("Уведомления разрешены")
        } else {
            LogManager.app.info("Уведомления не разрешены пользователем")
        }
    }

    /// Загрузка модели Whisper
    private func loadWhisperModel() async {
        do {
            LogManager.app.begin("Загрузка Whisper модели")
            try await container.whisperService.loadModel()

            // Загрузка промпта из настроек
            let userSettings = container.userSettings
            let effectivePrompt = userSettings.effectivePrompt
            if !effectivePrompt.isEmpty {
                container.whisperService.promptText = effectivePrompt
                LogManager.app.info(
                    "Промпт загружен из настроек (programming: \(userSettings.useProgrammingPrompt), custom: \(!userSettings.customPrompt.isEmpty))"
                )
            }

            LogManager.app.success("Whisper модель загружена")
        } catch {
            handleModelLoadError(error)
        }
    }

    // MARK: - Private Methods - Model Management

    /// Обработка изменения модели
    private func handleModelChange(newModelSize: String) async {
        LogManager.app.info("AppCoordinator: Запрос на смену модели на \(newModelSize)")

        do {
            try await container.whisperService.reloadModel(newModelSize: newModelSize)
            LogManager.app.success("AppCoordinator: Модель успешно изменена на \(newModelSize)")
        } catch {
            LogManager.app.failure("AppCoordinator: Смена модели", error: error)
            menuBarController.showError("Failed to change model: \(error.localizedDescription)")
        }
    }

    /// Обработка ошибки загрузки модели
    private func handleModelLoadError(_ error: Error) {
        LogManager.app.failure("Загрузка модели", error: error)
        let errorMessage = "Failed to load Whisper model: \(error.localizedDescription)"

        menuBarController.showError(errorMessage)
        container.notificationManager.showErrorNotification(message: errorMessage)
    }
}

// MARK: - MenuBarController Extensions

extension MenuBarController {
    /// Callback для запроса открытия настроек
    var onSettingsRequested: (() -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.onSettingsRequested) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.onSettingsRequested, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    private struct AssociatedKeys {
        static var onSettingsRequested = "onSettingsRequested"
    }
}
