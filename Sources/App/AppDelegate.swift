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
    private var floatingWindow: FloatingRecordingWindow?

    // Менеджеры
    private let audioDuckingManager = AudioDuckingManager.shared
    private let audioDeviceManager = AudioDeviceManager.shared
    private let micVolumeManager = MicrophoneVolumeManager.shared

    // Real-time транскрипция
    private var partialTranscriptionText: String = ""
    private var isTranscribingChunk = false  // Флаг для предотвращения параллельных транскрипций

    // Таймер для автоматической остановки записи
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

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
        whisperService = WhisperService(modelSize: "small")  // Лучше для смешанной речи RU+EN
        keyboardMonitor = KeyboardMonitor()
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

        if !status.accessibility {
            LogManager.app.failure("Accessibility не разрешен", message: "Требуется для CGEventTap")

            // Запрашиваем разрешение Accessibility
            PermissionManager.shared.requestAccessibilityPermission()

            menuBarController?.showError(
                PermissionManager.shared.showPermissionInstructions(for: .accessibility)
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

        // Callback для обработки аудио чанков в real-time
        audioService?.onAudioChunkReady = { [weak self] chunk in
            self?.handleAudioChunk(chunk)
        }

        let started = keyboardMonitor?.startMonitoring() ?? false
        if started {
            let hotkey = HotkeyManager.shared.currentHotkey.displayName
            LogManager.app.success("Мониторинг клавиатуры запущен", details: "Hotkey: \(hotkey)")
        } else {
            LogManager.app.failure("Мониторинг клавиатуры", message: "Не удалось запустить")
        }
    }

    // MARK: - Event Handlers

    /// Обработка нажатия горячей клавиши (начало записи)
    private func handleHotkeyPress() {
        let hotkey = HotkeyManager.shared.currentHotkey.displayName
        LogManager.app.info("=== \(hotkey) Pressed ===")

        // Сброс промежуточного текста
        partialTranscriptionText = ""
        isTranscribingChunk = false

        do {
            // Приглушаем системную музыку
            audioDuckingManager.duck()

            // Повышаем громкость микрофона до максимума
            micVolumeManager.boostMicrophoneVolume()

            try audioService?.startRecording()
            menuBarController?.updateIcon(recording: true)
            floatingWindow?.showRecording()  // Показываем всплывающее окно
            SoundManager.shared.play(.recordingStarted)

            // Запускаем таймер для автоматической остановки
            recordingStartTime = Date()
            startRecordingTimer()

            LogManager.app.success("Запись начата")
        } catch {
            LogManager.app.failure("Начало записи", error: error)
            let errorMessage = "Recording failed: \(error.localizedDescription)"

            // Показываем ошибку в floating window
            floatingWindow?.showError(errorMessage)

            menuBarController?.showError(errorMessage)

            // Восстанавливаем музыку и громкость микрофона при ошибке
            audioDuckingManager.unduck()
            micVolumeManager.restoreMicrophoneVolume()

            // Звук + уведомление об ошибке записи
            NotificationManager.shared.notifyError(
                message: errorMessage,
                playSound: true
            )
        }
    }

    /// Обработка аудио чанка для real-time транскрипции
    /// КУМУЛЯТИВНЫЙ ПОДХОД: chunk содержит ВСЁ накопленное аудио с начала записи
    private func handleAudioChunk(_ chunk: [Float]) {
        // Пропускаем если уже идет обработка предыдущего чанка
        guard !isTranscribingChunk else {
            LogManager.app.debug("Пропущен чанк (идет обработка предыдущего)")
            return
        }

        isTranscribingChunk = true
        let chunkDuration = Float(chunk.count) / 16000.0

        Task {
            do {
                // Быстрая транскрипция ВСЕГО накопленного аудио
                let fullText = try await whisperService?.transcribeChunk(audioSamples: chunk) ?? ""

                if !fullText.isEmpty {
                    // Проверяем на стоп-слова (включая "отмена")
                    if UserSettings.shared.containsStopWord(fullText) {
                        LogManager.app.info("🛑 Обнаружено стоп-слово - сброс буфера")

                        await MainActor.run {
                            // Сбрасываем буфер аудио
                            audioService?.clearBuffer()

                            // Очищаем текст
                            partialTranscriptionText = ""

                            // Показываем подсказку заново
                            floatingWindow?.updatePartialTranscription("")

                            // Звуковой сигнал об отмене
                            SoundManager.shared.play(.recordingStopped)
                        }
                    } else if UserSettings.shared.containsStopWord(fullText) {
                        // Проверка на другие стоп-слова
                        LogManager.app.info("🛑 Обнаружено стоп-слово - сброс буфера")

                        await MainActor.run {
                            audioService?.clearBuffer()
                            partialTranscriptionText = ""
                            floatingWindow?.updatePartialTranscription("")
                            SoundManager.shared.play(.recordingStopped)
                        }
                    } else {
                        await MainActor.run {
                            // ЗАМЕНЯЕМ текст полностью (не накапливаем!), т.к. транскрибируем всё аудио заново
                            partialTranscriptionText = fullText

                            // Обновляем UI
                            floatingWindow?.updatePartialTranscription(fullText)
                            LogManager.app.info("Кумулятивная транскрипция (\(String(format: "%.1f", chunkDuration))s): \"\(fullText)\"")
                        }
                    }
                }
            } catch {
                LogManager.app.error("Ошибка транскрипции чанка: \(error.localizedDescription)")
            }

            isTranscribingChunk = false
        }
    }

    /// Обработка отпускания горячей клавиши (остановка записи и транскрипция)
    private func handleHotkeyRelease() {
        let hotkey = HotkeyManager.shared.currentHotkey.displayName
        LogManager.app.info("=== \(hotkey) Released ===")

        // Останавливаем таймер
        stopRecordingTimer()

        guard let audioData = audioService?.stopRecording() else {
            LogManager.app.failure("Остановка записи", message: "Нет аудио данных")
            // Восстанавливаем музыку при ошибке
            audioDuckingManager.unduck()
            floatingWindow?.hide()  // Закрываем окно при ошибке
            return
        }

        menuBarController?.updateIcon(recording: false)
        SoundManager.shared.play(.recordingStopped)

        // Сразу скрываем окно после отпускания кнопки
        floatingWindow?.hide()

        // Показываем состояние обработки
        menuBarController?.updateProcessingState(true)

        // Запускаем транскрипцию асинхронно
        Task {
            await performTranscription(audioData: audioData)
        }
    }

    /// Выполнение транскрипции и вставка текста
    private func performTranscription(audioData: [Float]) async {
        let startTime = Date()

        // Проверка на тишину
        if SilenceDetector.shared.isSilence(audioData) {
            LogManager.transcription.info("🔇 Обнаружена тишина, транскрипция пропущена")

            await MainActor.run {
                menuBarController?.updateProcessingState(false)
                floatingWindow?.showError("No speech detected (silence)")
                SoundManager.shared.play(.transcriptionError)
                audioDuckingManager.unduck()
                micVolumeManager.restoreMicrophoneVolume()

                NotificationManager.shared.notifyError(
                    message: "No speech detected (silence)",
                    playSound: false
                )
            }
            return
        }

        do {
            LogManager.transcription.begin("Транскрипция")

            // Транскрипция через Whisper
            let transcription = try await whisperService?.transcribe(audioSamples: audioData) ?? ""

            let duration = Date().timeIntervalSince(startTime)

            // Проверяем на стоп-слова
            if UserSettings.shared.containsStopWord(transcription) {
                LogManager.transcription.info("🛑 Обнаружено стоп-слово - текст не вставлен")

                await MainActor.run {
                    // Убираем иконку обработки
                    menuBarController?.updateProcessingState(false)
                    floatingWindow?.hide()  // Просто закрываем окно
                    SoundManager.shared.play(.recordingStopped)  // Звук отмены
                    audioDuckingManager.unduck()
                    micVolumeManager.restoreMicrophoneVolume()
                }
                return
            }

            if !transcription.isEmpty {
                LogManager.transcription.success("Транскрипция завершена", details: "\"\(transcription)\" (за \(String(format: "%.1f", duration))с)")

                // Вставка текста в позицию курсора
                await MainActor.run {
                    textInserter?.insertTextAtCursor(transcription)

                    // Добавляем в историю
                    TranscriptionHistory.shared.addTranscription(transcription, duration: duration)

                    // Успех: убираем иконку обработки, воспроизводим звук, восстанавливаем музыку и микрофон
                    menuBarController?.updateProcessingState(false)
                    floatingWindow?.showResult(transcription, duration: duration)  // Показываем результат
                    SoundManager.shared.play(.transcriptionSuccess)
                    audioDuckingManager.unduck()
                    micVolumeManager.restoreMicrophoneVolume()

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
                    // Ошибка: убираем иконку обработки, воспроизводим звук ошибки, восстанавливаем музыку и микрофон
                    menuBarController?.updateProcessingState(false)
                    floatingWindow?.showError("No speech detected")  // Показываем ошибку
                    SoundManager.shared.play(.transcriptionError)
                    audioDuckingManager.unduck()
                    micVolumeManager.restoreMicrophoneVolume()

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
                // Ошибка: убираем иконку обработки, воспроизводим звук ошибки, восстанавливаем музыку и микрофон
                menuBarController?.updateProcessingState(false)
                floatingWindow?.showError(errorMessage)  // Показываем ошибку
                SoundManager.shared.play(.transcriptionError)
                audioDuckingManager.unduck()
                micVolumeManager.restoreMicrophoneVolume()

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

    // MARK: - Recording Timer

    /// Запуск таймера для автоматической остановки записи
    private func startRecordingTimer() {
        let maxDuration = UserSettings.shared.maxRecordingDuration

        recordingTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            LogManager.app.info("⏱️ Достигнута максимальная длительность записи (\(Int(maxDuration))s), автоматическая остановка")

            // Останавливаем запись автоматически
            self.handleHotkeyRelease()

            // Показываем уведомление пользователю
            DispatchQueue.main.async {
                NotificationManager.shared.showInfoNotification(
                    title: "Запись остановлена",
                    message: "Достигнута максимальная длительность записи (\(Int(maxDuration))s)"
                )
            }
        }

        LogManager.app.debug("Таймер записи запущен: \(Int(maxDuration))s")
    }

    /// Остановка таймера записи
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            LogManager.app.debug("Запись остановлена вручную после \(String(format: "%.1f", duration))s")
        }

        recordingStartTime = nil
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Terminating ===")
        stopRecordingTimer()
        keyboardMonitor?.stopMonitoring()
    }
}
