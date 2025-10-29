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
    private var fileTranscriptionService: FileTranscriptionService?

    // Храним массив окон транскрипции (strong references)
    private var fileTranscriptionWindows: [FileTranscriptionWindow] = []

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

        // LSUIElement в Info.plist уже скрывает приложение из Dock
        // НЕ устанавливаем activationPolicy, оставляем default (.regular)
        // Это позволит applicationShouldTerminateAfterLastWindowClosed работать корректно


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

        // Используем сохраненную настройку модели из UserSettings
        let modelSize = UserSettings.shared.whisperModelSize
        whisperService = WhisperService(modelSize: modelSize)
        LogManager.app.info("Инициализация WhisperService с моделью из настроек: \(modelSize)")

        keyboardMonitor = KeyboardMonitor()
        textInserter = TextInserter()
        floatingWindow = FloatingRecordingWindow()

        // Инициализируем сервисы транскрипции файлов (после whisperService!)
        if let whisperService = whisperService {
            fileTranscriptionService = FileTranscriptionService(whisperService: whisperService)
        }

        LogManager.app.success("Все сервисы инициализированы")
    }

    /// Настройка menu bar
    private func setupMenuBar() {
        menuBarController?.setupMenuBar()


        // Устанавливаем callback для смены модели
        menuBarController?.modelChangedCallback = { [weak self] newModelSize in
            guard let self = self else { return }
            LogManager.app.info("Запрос на смену модели на \(newModelSize)")

            Task {
                do {
                    try await self.whisperService?.reloadModel(newModelSize: newModelSize)
                    LogManager.app.success("Модель успешно изменена на \(newModelSize)")
                } catch {
                    LogManager.app.failure("Смена модели", error: error)
                }
            }
        }

        // Устанавливаем callback для транскрибации файлов
        menuBarController?.transcribeFilesCallback = { [weak self] files in
            guard let self = self else { return }

            // Создаём НОВОЕ окно для каждой транскрибации
            let newWindow = FileTranscriptionWindow()

            // ВАЖНО: Сохраняем strong reference чтобы окно не удалилось из памяти
            self.fileTranscriptionWindows.append(newWindow)

            // Настраиваем обработчик закрытия окна
            newWindow.onClose = { [weak self] window in
                // Удаляем окно из массива когда оно закрывается
                self?.fileTranscriptionWindows.removeAll { $0 === window }
            }

            DispatchQueue.main.async {
                newWindow.startTranscription(files: files)
            }

            // Запускаем транскрибацию в фоне
            Task {
                await self.transcribeFilesInWindow(files, window: newWindow)
            }
        }
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

        // 6. Настройка уведомлений для отладки Bluetooth
        setupDebugNotifications()

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

    /// Настройка уведомлений для отладки Bluetooth / AirPods режимов
    private func setupDebugNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugStartEngine"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // self?.audioService?.debugStartEngine()  // TODO: Добавить метод debugStartEngine
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugStopEngine"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // self?.audioService?.debugStopEngine()  // TODO: Добавить метод debugStopEngine
        }

        LogManager.app.info("Debug notifications настроены")
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

        // Сброс промежуточного текста и счетчика (начинаем с чистого листа)
        partialTranscriptionText = ""
        isTranscribingChunk = false
        audioService?.clearBuffer()  // Очистка буфера и сброс счетчика lastChunkProcessedAt

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
            let device = AudioDeviceManager.shared.selectedDevice
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

        // Логируем Bluetooth профиль ПЕРЕД остановкой записи (если используется Bluetooth)
        // TODO: Добавить проверку Bluetooth устройства когда добавим свойство isBluetooth
        /*
        if let selectedDevice = audioDeviceManager.getSelectedDeviceOrDefault(), selectedDevice.isBluetooth {
            LogManager.app.info("📱 Bluetooth устройство ДО stopRecording: \(selectedDevice.name)")
            BluetoothProfileMonitor.shared.logCurrentProfile(for: selectedDevice)
        }
        */

        // Останавливаем таймер
        stopRecordingTimer()

        guard let audioData = audioService?.stopRecording() else {
            LogManager.app.failure("Остановка записи", message: "Нет аудио данных")
            // Восстанавливаем музыку при ошибке
            let device = AudioDeviceManager.shared.selectedDevice
            audioDuckingManager.unduck()
            floatingWindow?.hide()  // Закрываем окно при ошибке
            return
        }

        // Логируем Bluetooth профиль ПОСЛЕ остановки записи (с небольшой задержкой)
        // TODO: Добавить проверку Bluetooth устройства когда добавим свойство isBluetooth
        /*
        if let selectedDevice = audioDeviceManager.getSelectedDeviceOrDefault(), selectedDevice.isBluetooth {
            // Даём macOS немного времени (0.5s) для переключения Bluetooth профиля
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                LogManager.app.info("📱 Bluetooth профиль ПОСЛЕ stopRecording (через 0.5s):")
                BluetoothProfileMonitor.shared.logCurrentProfile(for: selectedDevice)
            }
        }
        */

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
                let device = AudioDeviceManager.shared.selectedDevice
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
                    let device = AudioDeviceManager.shared.selectedDevice
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
                    let device = AudioDeviceManager.shared.selectedDevice
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
                    let device = AudioDeviceManager.shared.selectedDevice
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
                let device = AudioDeviceManager.shared.selectedDevice
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

    // MARK: - File Handling

    /// Обработка открытия файлов (drag-and-drop или открытие через Finder)
    func application(_ sender: NSApplication, open urls: [URL]) {
        LogManager.app.info("📁 File open request: \(urls.count) файлов")

        // Фильтруем только audio/video файлы
        let validFiles = urls.filter { url in
            let pathExtension = url.pathExtension.lowercased()
            let audioExtensions = ["m4a", "mp3", "wav", "aiff", "aac", "flac"]
            let videoExtensions = ["mp4", "mov", "avi", "mkv"]
            return audioExtensions.contains(pathExtension) || videoExtensions.contains(pathExtension)
        }

        if validFiles.isEmpty {
            LogManager.app.warning("Нет поддерживаемых файлов для транскрипции")
            menuBarController?.showError("Unsupported file type. Please drop audio or video files.")
            return
        }

        LogManager.app.success("Найдено \(validFiles.count) файлов для транскрипции")

        // Создаём новое окно для транскрибации
        let newWindow = FileTranscriptionWindow()

        // Сохраняем strong reference
        fileTranscriptionWindows.append(newWindow)

        // Настраиваем обработчик закрытия окна
        newWindow.onClose = { [weak self] window in
            self?.fileTranscriptionWindows.removeAll { $0 === window }
        }

        DispatchQueue.main.async {
            newWindow.startTranscription(files: validFiles)
        }

        // Запускаем транскрипцию асинхронно
        Task {
            await self.transcribeFilesInWindow(validFiles, window: newWindow)
        }
    }

    /// Транскрибирует список файлов последовательно в указанном окне
    private func transcribeFilesInWindow(_ files: [URL], window: FileTranscriptionWindow) async {
        guard let service = fileTranscriptionService else {
            LogManager.app.failure("FileTranscriptionService", message: "не инициализирован")
            return
        }

        // Устанавливаем информацию о модели Whisper в окне
        if let modelSize = whisperService?.currentModelSize {
            await MainActor.run {
                window.viewModel.setModel(modelSize)
            }
        }

        for (index, fileURL) in files.enumerated() {
            let fileName = fileURL.lastPathComponent
            let progress = Double(index) / Double(files.count)

            // Обновляем прогресс
            await MainActor.run {
                window.viewModel.updateProgress(file: fileName, progress: progress)
            }

            LogManager.app.begin("Транскрипция файла \(index + 1)/\(files.count): \(fileName)")

            do {
                // Создаем нормализованную копию файла СНАЧАЛА для улучшения качества
                let normalizedURL = try AudioFileNormalizer.createNormalizedCopy(of: fileURL)

                // Устанавливаем callback для промежуточных обновлений с нормализованным URL
                service.onProgressUpdate = { [weak window] fileName, segmentProgress, partialDialogue in
                    guard let dialogue = partialDialogue else { return }
                    Task { @MainActor in
                        window?.viewModel.updateDialogue(file: fileName, dialogue: dialogue, fileURL: normalizedURL)
                        window?.viewModel.updateProgress(file: fileName, progress: segmentProgress)
                    }
                }

                // Используем нормализованный файл для транскрипции
                let dialogue = try await service.transcribeFileWithDialogue(at: normalizedURL)

                await MainActor.run {
                    // Финальное обновление диалога с URL нормализованного файла для плеера
                    window.viewModel.updateDialogue(file: fileName, dialogue: dialogue, fileURL: normalizedURL)
                    LogManager.app.success("Файл транскрибирован: \(fileName) (\(dialogue.isStereo ? "стерео диалог" : "моно"))")
                }
            } catch {
                LogManager.app.failure("Ошибка транскрипции \(fileName)", error: error)

                await MainActor.run {
                    window.viewModel.addError(file: fileName, error: error.localizedDescription)
                }
            }

            // Очищаем callback
            service.onProgressUpdate = nil
        }

        // Завершаем транскрипцию
        await MainActor.run {
            window.viewModel.complete()
            LogManager.app.success("Все файлы обработаны (\(files.count) шт.)")
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
    }

    /// Остановка таймера записи
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    // MARK: - Cleanup

    /// Предотвращаем автоматическое завершение приложения при закрытии последнего окна
    /// Приложение должно работать пока пользователь не выберет Quit из menu bar
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // НЕ завершаем приложение при закрытии окон
    }

    func applicationWillTerminate(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Terminating ===")

        // Логируем текущий Bluetooth профиль перед выходом (если используется Bluetooth устройство)
        // TODO: Добавить проверку Bluetooth устройства когда добавим свойство isBluetooth
        /*
        if let selectedDevice = audioDeviceManager.getSelectedDeviceOrDefault(), selectedDevice.isBluetooth {
            LogManager.app.info("📱 Текущее Bluetooth устройство: \(selectedDevice.name)")
            BluetoothProfileMonitor.shared.logCurrentProfile(for: selectedDevice)
        }
        */

        // Останавливаем таймер записи
        stopRecordingTimer()

        // Останавливаем мониторинг клавиатуры
        keyboardMonitor?.stopMonitoring()

        // КРИТИЧНО для AirPods: Полностью останавливаем audio engine для освобождения микрофона
        // Без этого AirPods остаются в SCO (mono) режиме даже после закрытия приложения
        // audioService?.cleanup()  // TODO: Добавить метод cleanup

        // Останавливаем мониторинг Bluetooth профиля
        // BluetoothProfileMonitor.shared.stopMonitoring()

        // ВАЖНО: Восстанавливаем громкость системы, если она была приглушена
        // TODO: Исправить scope issues с audioDuckingManager
        /*
        if audioDuckingManager.isDucked {
            LogManager.app.warning("Приложение закрывается с активным ducking - форсируем восстановление громкости")
            // Используем прямое восстановление без задержек для немедленного эффекта
            audioDuckingManager.forceUnduck()
        }
        */

        // Восстанавливаем громкость микрофона
        // micVolumeManager.restoreMicrophoneVolume()  // TODO: Исправить scope ошибку

        // Логируем финальный Bluetooth профиль после cleanup (для отладки)
        // TODO: Добавить проверку Bluetooth устройства когда добавим свойство isBluetooth
        /*
        if let selectedDevice = audioDeviceManager.getSelectedDeviceOrDefault(), selectedDevice.isBluetooth {
            LogManager.app.info("📱 Bluetooth профиль ПОСЛЕ cleanup:")
            BluetoothProfileMonitor.shared.logCurrentProfile(for: selectedDevice)
        }
        */

        LogManager.app.info("=== Cleanup завершен ===")
    }
}
