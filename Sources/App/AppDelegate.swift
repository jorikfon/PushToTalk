import Cocoa
import SwiftUI
import PushToTalkCore

/// Главный делегат приложения
/// Управляет жизненным циклом и координирует все сервисы
class AppDelegate: NSObject, NSApplicationDelegate {
    // Сервисы
    private var menuBarController: MenuBarController?
    private var audioService: AudioCaptureService?
    private var whisperService: WhisperService?
    private var keyboardMonitor: KeyboardMonitor?
    private var mediaKeyMonitor: MediaKeyMonitor?
    private var textInserter: TextInserter?
    private var floatingWindow: FloatingRecordingWindow?

    // Менеджеры
    private let audioDuckingManager = AudioDuckingManager.shared
    private let audioDeviceManager = AudioDeviceManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Starting ===")

        // Скрываем иконку из Dock (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Инициализация сервисов
        initializeServices()

        // Настройка menu bar
        setupMenuBar()

        // Асинхронная инициализация
        Task {
            await asyncInitialization()
        }
    }

    // MARK: - Initialization

    /// Инициализация всех сервисов
    private func initializeServices() {
        menuBarController = MenuBarController()
        audioService = AudioCaptureService()
        whisperService = WhisperService(modelSize: "tiny")
        keyboardMonitor = KeyboardMonitor()
        mediaKeyMonitor = MediaKeyMonitor()
        textInserter = TextInserter()
        floatingWindow = FloatingRecordingWindow()

        LogManager.app.success("Все сервисы инициализированы")
    }

    /// Настройка menu bar
    private func setupMenuBar() {
        menuBarController?.setupMenuBar()
    }

    /// Асинхронная инициализация (загрузка модели, проверка разрешений)
    private func asyncInitialization() async {
        // 1. Проверка разрешений
        await checkPermissions()

        // 2. Настройка уведомлений
        await setupNotifications()

        // 3. Загрузка Whisper модели
        await loadWhisperModel()

        // 4. Запуск мониторинга клавиатуры
        setupKeyboardMonitoring()

        // 5. Настройка уведомлений для тестовой записи
        setupTestRecordingNotifications()

        LogManager.app.success("Инициализация завершена")
    }

    /// Настройка уведомлений для тестовой записи из UI
    private func setupTestRecordingNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StartTestRecording"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startRecording()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StopTestRecording"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopRecording()
        }

        LogManager.app.info("Test recording notifications настроены")
    }

    /// Проверка всех необходимых разрешений
    private func checkPermissions() async {
        let status = await PermissionManager.shared.checkAllPermissions()

        // Важно: нужно также вызвать checkPermissions на audioService
        // чтобы установить его внутренний флаг permissionGranted
        if status.microphone {
            _ = await audioService?.checkPermissions()
        }

        if !status.microphone {
            menuBarController?.showError(
                PermissionManager.shared.showPermissionInstructions(for: .microphone)
            )
        }
    }

    /// Настройка системы уведомлений
    private func setupNotifications() async {
        // Настройка категорий уведомлений
        NotificationManager.shared.setupNotificationCategories()

        // Запрос разрешения на уведомления
        let granted = await NotificationManager.shared.requestPermission()

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
            try await whisperService?.loadModel()

            // Загружаем промпт из настроек (встроенный + пользовательский)
            let effectivePrompt = UserSettings.shared.effectivePrompt
            if !effectivePrompt.isEmpty {
                whisperService?.promptText = effectivePrompt
                LogManager.app.info("Промпт загружен из настроек (programming: \(UserSettings.shared.useProgrammingPrompt), custom: \(!UserSettings.shared.customPrompt.isEmpty))")
            }

            LogManager.app.success("Whisper модель загружена")
        } catch {
            LogManager.app.failure("Загрузка модели", error: error)
            let errorMessage = "Failed to load Whisper model: \(error.localizedDescription)"
            menuBarController?.showError(errorMessage)

            // Уведомление об ошибке загрузки модели
            NotificationManager.shared.showErrorNotification(message: errorMessage)
        }
    }

    /// Настройка мониторинга клавиатуры (Carbon API - не требует Accessibility разрешений)
    private func setupKeyboardMonitoring() {
        // Мониторинг F16 (или другой настроенной клавиши)
        keyboardMonitor?.onHotkeyPress = { [weak self] in
            self?.handleHotkeyPress()
        }

        keyboardMonitor?.onHotkeyRelease = { [weak self] in
            self?.handleHotkeyRelease()
        }

        let started = keyboardMonitor?.startMonitoring() ?? false
        if started {
            let hotkey = HotkeyManager.shared.currentHotkey.displayName
            LogManager.app.success("Мониторинг клавиатуры запущен", details: "Hotkey: \(hotkey)")
        } else {
            LogManager.app.failure("Мониторинг клавиатуры", message: "Не удалось запустить")
        }

        // Мониторинг медиа-кнопок (EarPods Play/Pause)
        // ТРЕБУЕТ Accessibility разрешений
        // Push-to-talk стиль: держишь кнопку - записывает, отпустил - останавливает
        mediaKeyMonitor?.onPlayPausePress = { [weak self] in
            self?.handleHotkeyPress()
        }

        mediaKeyMonitor?.onPlayPauseRelease = { [weak self] in
            self?.handleHotkeyRelease()
        }

        let mediaStarted = mediaKeyMonitor?.startMonitoring() ?? false
        if mediaStarted {
            LogManager.app.success("Мониторинг медиа-кнопок запущен", details: "EarPods Play/Pause (push-to-talk)")
        } else {
            LogManager.app.info("Мониторинг медиа-кнопок не запущен (требуются Accessibility разрешения)")
        }
    }

    // MARK: - Event Handlers

    /// Обработка нажатия горячей клавиши (начало записи)
    private func handleHotkeyPress() {
        let hotkey = HotkeyManager.shared.currentHotkey.displayName
        LogManager.app.info("=== \(hotkey) Pressed ===")

        do {
            // Приглушаем системную музыку
            audioDuckingManager.duck()

            try audioService?.startRecording()
            menuBarController?.updateIcon(recording: true)
            floatingWindow?.showRecording()  // Показываем всплывающее окно
            SoundManager.shared.play(.recordingStarted)
            LogManager.app.success("Запись начата")
        } catch {
            LogManager.app.failure("Начало записи", error: error)
            let errorMessage = "Recording failed: \(error.localizedDescription)"

            // Показываем ошибку в floating window
            floatingWindow?.showError(errorMessage)

            menuBarController?.showError(errorMessage)

            // Восстанавливаем музыку при ошибке
            audioDuckingManager.unduck()

            // Звук + уведомление об ошибке записи
            NotificationManager.shared.notifyError(
                message: errorMessage,
                playSound: true
            )
        }
    }

    /// Обработка отпускания горячей клавиши (остановка записи и транскрипция)
    private func handleHotkeyRelease() {
        let hotkey = HotkeyManager.shared.currentHotkey.displayName
        LogManager.app.info("=== \(hotkey) Released ===")

        guard let audioData = audioService?.stopRecording() else {
            LogManager.app.failure("Остановка записи", message: "Нет аудио данных")
            // Восстанавливаем музыку при ошибке
            audioDuckingManager.unduck()
            return
        }

        menuBarController?.updateIcon(recording: false)
        SoundManager.shared.play(.recordingStopped)

        // Показываем состояние обработки
        menuBarController?.updateProcessingState(true)
        floatingWindow?.showProcessing()  // Обновляем floating window

        // Запускаем транскрипцию асинхронно
        Task {
            await performTranscription(audioData: audioData)
        }
    }

    /// Выполнение транскрипции и вставка текста
    private func performTranscription(audioData: [Float]) async {
        let startTime = Date()

        do {
            LogManager.transcription.begin("Транскрипция")

            // Транскрипция через Whisper
            let transcription = try await whisperService?.transcribe(audioSamples: audioData) ?? ""

            let duration = Date().timeIntervalSince(startTime)

            if !transcription.isEmpty {
                LogManager.transcription.success("Транскрипция завершена", details: "\"\(transcription)\" (за \(String(format: "%.1f", duration))с)")

                // Вставка текста в позицию курсора
                await MainActor.run {
                    textInserter?.insertTextAtCursor(transcription)

                    // Добавляем в историю
                    TranscriptionHistory.shared.addTranscription(transcription, duration: duration)

                    // Успех: убираем иконку обработки, воспроизводим звук, восстанавливаем музыку
                    menuBarController?.updateProcessingState(false)
                    floatingWindow?.showResult(transcription, duration: duration)  // Показываем результат
                    SoundManager.shared.play(.transcriptionSuccess)
                    audioDuckingManager.unduck()

                    // Уведомление об успехе
                    NotificationManager.shared.notifyTranscriptionSuccess(
                        text: transcription,
                        duration: duration,
                        playSound: false  // Звук уже воспроизвели выше
                    )
                }
            } else {
                LogManager.transcription.failure("Транскрипция", message: "Пустой результат")
                await MainActor.run {
                    // Ошибка: убираем иконку обработки, воспроизводим звук ошибки, восстанавливаем музыку
                    menuBarController?.updateProcessingState(false)
                    floatingWindow?.showError("No speech detected")  // Показываем ошибку
                    SoundManager.shared.play(.transcriptionError)
                    audioDuckingManager.unduck()

                    // Уведомление об ошибке
                    NotificationManager.shared.notifyError(
                        message: "No speech detected",
                        playSound: false  // Звук уже воспроизвели выше
                    )
                }
            }
        } catch {
            LogManager.transcription.failure("Транскрипция", error: error)
            let errorMessage = "Transcription failed: \(error.localizedDescription)"
            await MainActor.run {
                // Ошибка: убираем иконку обработки, воспроизводим звук ошибки, восстанавливаем музыку
                menuBarController?.updateProcessingState(false)
                floatingWindow?.showError(errorMessage)  // Показываем ошибку
                SoundManager.shared.play(.transcriptionError)
                audioDuckingManager.unduck()

                menuBarController?.showError(errorMessage)

                // Уведомление об ошибке
                NotificationManager.shared.notifyError(
                    message: errorMessage,
                    playSound: false  // Звук уже воспроизвели выше
                )
            }
        }
    }

    // MARK: - Public Test Methods

    /// Публичный метод для тестовой записи (вызывается из UI)
    public func startRecording() {
        LogManager.app.info("🎤 PUBLIC: Starting test recording")
        handleHotkeyPress()
    }

    /// Публичный метод для остановки тестовой записи (вызывается из UI)
    public func stopRecording() {
        LogManager.app.info("🎤 PUBLIC: Stopping test recording")
        handleHotkeyRelease()
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Terminating ===")
        keyboardMonitor?.stopMonitoring()
        mediaKeyMonitor?.stopMonitoring()
    }
}
