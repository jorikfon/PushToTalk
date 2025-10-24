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
    private var textInserter: TextInserter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("=== PushToTalk Starting ===")

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
        textInserter = TextInserter()

        print("AppDelegate: ✓ Все сервисы инициализированы")
    }

    /// Настройка menu bar
    private func setupMenuBar() {
        menuBarController?.setupMenuBar()
    }

    /// Асинхронная инициализация (загрузка модели, проверка разрешений)
    private func asyncInitialization() async {
        // 1. Проверка разрешений
        await checkPermissions()

        // 2. Загрузка Whisper модели
        await loadWhisperModel()

        // 3. Запуск мониторинга клавиатуры
        setupKeyboardMonitoring()

        print("AppDelegate: ✓ Инициализация завершена")
        menuBarController?.showInfo(
            "PushToTalk Ready",
            message: "Press and hold F16 to start recording"
        )
    }

    /// Проверка всех необходимых разрешений
    private func checkPermissions() async {
        let status = await PermissionManager.shared.checkAllPermissions()

        print(status.description)

        if !status.microphone {
            menuBarController?.showError(
                PermissionManager.shared.showPermissionInstructions(for: .microphone)
            )
        }

        if !status.accessibility {
            menuBarController?.showError(
                PermissionManager.shared.showPermissionInstructions(for: .accessibility)
            )
        }
    }

    /// Загрузка модели Whisper
    private func loadWhisperModel() async {
        do {
            print("AppDelegate: Загрузка Whisper модели...")
            try await whisperService?.loadModel()
            print("AppDelegate: ✓ Whisper модель загружена")
        } catch {
            print("AppDelegate: ✗ Ошибка загрузки модели: \(error)")
            menuBarController?.showError("Failed to load Whisper model: \(error.localizedDescription)")
        }
    }

    /// Настройка мониторинга клавиатуры
    private func setupKeyboardMonitoring() {
        keyboardMonitor?.onF16Press = { [weak self] in
            self?.handleF16Press()
        }

        keyboardMonitor?.onF16Release = { [weak self] in
            self?.handleF16Release()
        }

        let started = keyboardMonitor?.startMonitoring() ?? false
        if started {
            print("AppDelegate: ✓ Мониторинг клавиатуры запущен")
        } else {
            print("AppDelegate: ✗ Не удалось запустить мониторинг клавиатуры")
        }
    }

    // MARK: - Event Handlers

    /// Обработка нажатия F16 (начало записи)
    private func handleF16Press() {
        print("\n=== F16 Pressed ===")

        do {
            try audioService?.startRecording()
            menuBarController?.updateIcon(recording: true)
            SoundManager.shared.play(.recordingStarted)
            print("AppDelegate: ✓ Запись начата")
        } catch {
            print("AppDelegate: ✗ Ошибка начала записи: \(error)")
            menuBarController?.showError("Recording failed: \(error.localizedDescription)")
            SoundManager.shared.play(.transcriptionError)
        }
    }

    /// Обработка отпускания F16 (остановка записи и транскрипция)
    private func handleF16Release() {
        print("\n=== F16 Released ===")

        guard let audioData = audioService?.stopRecording() else {
            print("AppDelegate: ✗ Нет аудио данных")
            return
        }

        menuBarController?.updateIcon(recording: false)
        SoundManager.shared.play(.recordingStopped)

        // Запускаем транскрипцию асинхронно
        Task {
            await performTranscription(audioData: audioData)
        }
    }

    /// Выполнение транскрипции и вставка текста
    private func performTranscription(audioData: [Float]) async {
        do {
            print("AppDelegate: Транскрипция...")

            // Транскрипция через Whisper
            let transcription = try await whisperService?.transcribe(audioSamples: audioData) ?? ""

            if !transcription.isEmpty {
                print("AppDelegate: ✓ Транскрипция: \"\(transcription)\"")

                // Вставка текста в позицию курсора
                await MainActor.run {
                    textInserter?.insertTextAtCursor(transcription)
                    SoundManager.shared.play(.transcriptionSuccess)
                }
            } else {
                print("AppDelegate: ⚠️ Пустая транскрипция")
                await MainActor.run {
                    SoundManager.shared.play(.transcriptionError)
                }
            }
        } catch {
            print("AppDelegate: ✗ Ошибка транскрипции: \(error)")
            await MainActor.run {
                menuBarController?.showError("Transcription failed: \(error.localizedDescription)")
                SoundManager.shared.play(.transcriptionError)
            }
        }
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        print("\n=== PushToTalk Terminating ===")
        keyboardMonitor?.stopMonitoring()
    }
}
