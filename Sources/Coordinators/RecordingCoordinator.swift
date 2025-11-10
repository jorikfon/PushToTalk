import Foundation
import Cocoa
import PushToTalkCore

/// Координатор для управления записью аудио и транскрипцией
/// Инкапсулирует всю бизнес-логику цикла записи: start → real-time processing → stop → transcription → text insertion
///
/// Отвечает за:
/// - Управление жизненным циклом записи (start/stop)
/// - Real-time транскрипцию аудио чанков
/// - Финальную транскрипцию с вставкой текста
/// - Координацию аудио эффектов (ducking, volume boost, sound feedback)
/// - Проверку стоп-слов и детекцию тишины
/// - Таймер автоматической остановки записи
/// - Обновление UI (menu bar, floating window)
public final class RecordingCoordinator {
    // MARK: - Dependencies (Protocol-based DI)

    private let audioService: AudioCaptureServiceProtocol
    private let whisperService: WhisperServiceProtocol
    private let textInserter: TextInserterProtocol
    private let menuBarController: MenuBarController
    private let floatingWindow: FloatingRecordingWindow

    // MARK: - Managers

    private let audioDuckingManager: AudioDuckingManager
    private let micVolumeManager: MicrophoneVolumeManager
    private let audioFeedbackManager: AudioFeedbackManager
    private let soundManager: SoundManager
    private let notificationManager: NotificationManager
    private let silenceDetector: SilenceDetector
    private let userSettings: UserSettings
    private let transcriptionHistory: TranscriptionHistory

    // MARK: - State

    /// Накопленный текст real-time транскрипции
    private var partialTranscriptionText: String = ""

    /// Флаг для предотвращения параллельных транскрипций чанков
    private var isTranscribingChunk = false

    /// Таймер для автоматической остановки записи
    private var recordingTimer: Timer?

    /// Время начала записи
    private var recordingStartTime: Date?

    /// Флаг активной записи
    public private(set) var isRecording = false

    // MARK: - Initialization

    public init(
        audioService: AudioCaptureServiceProtocol,
        whisperService: WhisperServiceProtocol,
        textInserter: TextInserterProtocol,
        menuBarController: MenuBarController,
        floatingWindow: FloatingRecordingWindow,
        audioDuckingManager: AudioDuckingManager = .shared,
        micVolumeManager: MicrophoneVolumeManager = .shared,
        audioFeedbackManager: AudioFeedbackManager = .shared,
        soundManager: SoundManager = .shared,
        notificationManager: NotificationManager = .shared,
        silenceDetector: SilenceDetector = .shared,
        userSettings: UserSettings = .shared,
        transcriptionHistory: TranscriptionHistory = .shared
    ) {
        self.audioService = audioService
        self.whisperService = whisperService
        self.textInserter = textInserter
        self.menuBarController = menuBarController
        self.floatingWindow = floatingWindow
        self.audioDuckingManager = audioDuckingManager
        self.micVolumeManager = micVolumeManager
        self.audioFeedbackManager = audioFeedbackManager
        self.soundManager = soundManager
        self.notificationManager = notificationManager
        self.silenceDetector = silenceDetector
        self.userSettings = userSettings
        self.transcriptionHistory = transcriptionHistory
    }

    // MARK: - Public API

    /// Начать запись аудио
    /// Вызывается при нажатии hotkey или из UI
    public func startRecording() {
        guard !isRecording else {
            LogManager.app.info("⏭️ Запись уже идет, пропускаем startRecording()")
            return
        }

        LogManager.app.info("=== Начало записи ===")

        // Сброс состояния (начинаем с чистого листа)
        resetState()

        do {
            // Подготовка аудио окружения
            prepareAudioEnvironment()

            // Запуск записи
            try audioService.startRecording()
            isRecording = true

            // Обновление UI
            updateUIForRecordingState(recording: true)

            // Запуск таймера автоматической остановки
            startRecordingTimer()

            LogManager.app.success("Запись начата")
        } catch {
            handleRecordingError(error)
        }
    }

    /// Остановить запись и выполнить транскрипцию
    /// Вызывается при отпускании hotkey или из UI
    public func stopRecording() {
        guard isRecording else {
            LogManager.app.info("⏭️ Запись не идет, пропускаем stopRecording()")
            return
        }

        LogManager.app.info("=== Остановка записи ===")

        // Остановка таймера
        stopRecordingTimer()

        // Получение записанного аудио
        let audioData = audioService.stopRecording()

        // Проверка на пустой буфер
        if audioData.isEmpty {
            handleStopRecordingError()
            return
        }

        isRecording = false

        // Обновление UI и воспроизведение звуков
        updateUIForRecordingState(recording: false)

        // Восстановление аудио окружения
        restoreAudioEnvironment()

        // Показ состояния обработки
        showProcessingState()

        // Асинхронная транскрипция
        Task {
            await performTranscription(audioData: audioData)
        }
    }

    /// Обработка аудио чанка для real-time транскрипции
    /// ВАЖНО: chunk содержит ВСЁ накопленное аудио с начала записи (кумулятивный подход)
    public func handleAudioChunk(_ chunk: [Float]) {
        // Пропускаем если уже идет обработка предыдущего чанка
        guard !isTranscribingChunk else {
            return
        }

        isTranscribingChunk = true
        let chunkDuration = Float(chunk.count) / Float(AppConstants.Audio.whisperSampleRate)

        Task {
            do {
                // Быстрая транскрипция ВСЕГО накопленного аудио
                let fullText = try await whisperService.transcribeChunk(audioSamples: chunk)

                if !fullText.isEmpty {
                    await handleTranscribedChunk(fullText, duration: chunkDuration)
                }
            } catch {
                LogManager.app.error("Ошибка транскрипции чанка: \(error.localizedDescription)")
            }

            isTranscribingChunk = false
        }
    }

    // MARK: - Private Methods - State Management

    /// Сброс состояния координатора
    private func resetState() {
        partialTranscriptionText = ""
        isTranscribingChunk = false
        audioService.clearBuffer()
    }

    /// Обработка транскрибированного чанка
    private func handleTranscribedChunk(_ text: String, duration: Float) async {
        // Проверка на стоп-слова
        if userSettings.containsStopWord(text) {
            await handleStopWordDetected()
        } else {
            await updatePartialTranscription(text, duration: duration)
        }
    }

    /// Обработка обнаружения стоп-слова
    private func handleStopWordDetected() async {
        LogManager.app.info("🛑 Обнаружено стоп-слово - сброс буфера")

        await MainActor.run {
            // Сброс буфера и состояния
            audioService.clearBuffer()
            partialTranscriptionText = ""
            floatingWindow.updatePartialTranscription("")
            floatingWindow.resetTimer()

            // Звуковой сигнал об отмене
            soundManager.play(.recordingStopped)
        }
    }

    /// Обновление частичной транскрипции в UI
    private func updatePartialTranscription(_ text: String, duration: Float) async {
        await MainActor.run {
            // ЗАМЕНЯЕМ текст полностью (не накапливаем!), т.к. транскрибируем всё аудио заново
            partialTranscriptionText = text
            floatingWindow.updatePartialTranscription(text)

            LogManager.app.info("Кумулятивная транскрипция (\(String(format: "%.1f", duration))s): \"\(text)\"")
        }
    }

    // MARK: - Private Methods - Audio Environment

    /// Подготовка аудио окружения для записи
    private func prepareAudioEnvironment() {
        // Приглушение системной музыки
        audioDuckingManager.duck()

        // Повышение громкости микрофона
        micVolumeManager.boostMicrophoneVolume()
    }

    /// Восстановление аудио окружения после записи
    private func restoreAudioEnvironment() {
        audioDuckingManager.unduck()
        micVolumeManager.restoreMicrophoneVolume()
    }

    // MARK: - Private Methods - UI Updates

    /// Обновление UI для состояния записи
    private func updateUIForRecordingState(recording: Bool) {
        menuBarController.updateIcon(recording: recording)

        if recording {
            // Показ floating window с таймером
            let maxDuration = userSettings.maxRecordingDuration
            floatingWindow.showRecording(maxDuration: maxDuration)

            // Звуковые эффекты
            soundManager.play(.recordingStarted)
            audioFeedbackManager.playStartSound()
        } else {
            // Звуковые эффекты остановки
            soundManager.play(.recordingStopped)
            audioFeedbackManager.playStopSound()
        }
    }

    /// Показ состояния обработки
    private func showProcessingState() {
        menuBarController.updateProcessingState(true)
        floatingWindow.showProcessing()
        audioFeedbackManager.startProcessingSound()
    }

    /// Скрытие состояния обработки
    private func hideProcessingState() {
        menuBarController.updateProcessingState(false)
        floatingWindow.hide()
        audioFeedbackManager.stopProcessingSound()
    }

    // MARK: - Private Methods - Transcription

    /// Выполнение финальной транскрипции и вставка текста
    private func performTranscription(audioData: [Float]) async {
        let startTime = Date()

        // Проверка на тишину
        if silenceDetector.isSilence(audioData) {
            await handleSilenceDetected()
            return
        }

        do {
            LogManager.transcription.begin("Транскрипция")

            // Транскрипция через Whisper
            let transcription = try await whisperService.transcribe(audioSamples: audioData)
            let duration = Date().timeIntervalSince(startTime)

            // Проверка на стоп-слова
            if userSettings.containsStopWord(transcription) {
                await handleStopWordInTranscription()
                return
            }

            // Обработка результата
            if !transcription.isEmpty {
                await handleSuccessfulTranscription(transcription, duration: duration)
            } else {
                await handleEmptyTranscription()
            }
        } catch {
            await handleTranscriptionError(error)
        }
    }

    /// Обработка обнаружения тишины
    private func handleSilenceDetected() async {
        LogManager.transcription.info("🔇 Обнаружена тишина, транскрипция пропущена")

        await MainActor.run {
            hideProcessingState()
            audioFeedbackManager.playErrorSound()
            soundManager.play(.transcriptionError)

            notificationManager.notifyError(
                message: "No speech detected (silence)",
                playSound: false
            )
        }
    }

    /// Обработка стоп-слова в финальной транскрипции
    private func handleStopWordInTranscription() async {
        LogManager.transcription.info("🛑 Обнаружено стоп-слово - текст не вставлен")

        await MainActor.run {
            hideProcessingState()
            soundManager.play(.recordingStopped)
        }
    }

    /// Обработка успешной транскрипции
    private func handleSuccessfulTranscription(_ text: String, duration: TimeInterval) async {
        LogManager.transcription.success(
            "Транскрипция завершена",
            details: "\"\(text)\" (за \(String(format: "%.1f", duration))с)"
        )

        await MainActor.run {
            // Остановка звуков обработки
            hideProcessingState()
            audioFeedbackManager.playSuccessSound()

            // Вставка текста
            textInserter.insertTextAtCursor(text)

            // Добавление в историю
            transcriptionHistory.addTranscription(text, duration: duration)

            // UI и звуковая обратная связь
            soundManager.play(.transcriptionSuccess)

            // Уведомление
            notificationManager.notifyTranscriptionSuccess(
                text: text,
                duration: duration,
                playSound: false
            )
        }
    }

    /// Обработка пустой транскрипции
    private func handleEmptyTranscription() async {
        LogManager.transcription.failure("Транскрипция", message: "Пустой результат")

        await MainActor.run {
            hideProcessingState()
            audioFeedbackManager.playErrorSound()
            soundManager.play(.transcriptionError)

            notificationManager.notifyError(
                message: "No speech detected",
                playSound: false
            )
        }
    }

    /// Обработка ошибки транскрипции
    private func handleTranscriptionError(_ error: Error) async {
        LogManager.transcription.failure("Транскрипция", error: error)
        let errorMessage = "Transcription failed: \(error.localizedDescription)"

        await MainActor.run {
            hideProcessingState()
            audioFeedbackManager.playErrorSound()
            soundManager.play(.transcriptionError)

            menuBarController.showError(errorMessage)

            notificationManager.notifyError(
                message: errorMessage,
                playSound: false
            )
        }
    }

    // MARK: - Private Methods - Error Handling

    /// Обработка ошибки начала записи
    private func handleRecordingError(_ error: Error) {
        LogManager.app.failure("Начало записи", error: error)
        let errorMessage = "Recording failed: \(error.localizedDescription)"

        isRecording = false

        // Показ ошибки
        floatingWindow.showError(errorMessage)
        menuBarController.showError(errorMessage)

        // Восстановление аудио окружения
        restoreAudioEnvironment()

        // Уведомление об ошибке
        notificationManager.notifyError(
            message: errorMessage,
            playSound: true
        )
    }

    /// Обработка ошибки остановки записи (нет аудио данных)
    private func handleStopRecordingError() {
        LogManager.app.failure("Остановка записи", message: "Нет аудио данных")

        isRecording = false

        // Восстановление и скрытие UI
        restoreAudioEnvironment()
        floatingWindow.hide()
    }

    // MARK: - Private Methods - Recording Timer

    /// Запуск таймера автоматической остановки записи
    private func startRecordingTimer() {
        let maxDuration = userSettings.maxRecordingDuration

        recordingStartTime = Date()
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: maxDuration,
            repeats: false
        ) { [weak self] _ in
            self?.handleRecordingTimeout(maxDuration: maxDuration)
        }
    }

    /// Остановка таймера записи
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    /// Обработка таймаута записи
    private func handleRecordingTimeout(maxDuration: TimeInterval) {
        LogManager.app.info("⏱️ Достигнута максимальная длительность записи (\(Int(maxDuration))s), автоматическая остановка")

        // Останавливаем запись
        stopRecording()

        // Показываем уведомление
        DispatchQueue.main.async { [weak self] in
            self?.notificationManager.showInfoNotification(
                title: "Запись остановлена",
                message: "Достигнута максимальная длительность записи (\(Int(maxDuration))s)"
            )
        }
    }
}
