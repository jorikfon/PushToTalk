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

    /// Идентификатор текущей записи. Инкрементируется при старте новой записи,
    /// чтобы поздние результаты превью от ПРЕДЫДУЩЕЙ записи (cancel() не
    /// останавливает уже идущий transcribeChunk) были отброшены, а не вставлены.
    private var recordingSession: Int = 0

    /// Сколько сэмплов уже покрыто последней транскрипцией превью.
    /// Используется на отпускании, чтобы решить: переиспользовать готовый
    /// результат (если хвост — тишина) или сделать финальный проход.
    private var lastTranscribedSampleCount: Int = 0

    /// Спекулятивная транскрипция, запущенная по паузе. На отпускании мы её
    /// ДОЖИДАЕМСЯ (overlap+reuse), а не выбрасываем и запускаем заново.
    private var inFlightChunkTask: Task<Void, Never>?

    /// Сколько сэмплов покроет текущая (ещё идущая) транскрипция превью.
    /// На отпускании по нему решаем, имеет ли смысл ждать превью или сразу
    /// делать финальный проход (если хвост после снапшота — речь).
    private var inFlightSnapshotCount: Int = 0

    /// Инструментация: сколько раз переиспользовали превью vs делали финальный проход
    private var reuseHitCount = 0
    private var finalPassCount = 0

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

        // Показ состояния обработки
        showProcessingState()

        // Сессия завершаемой записи. Фиксируем синхронно здесь (события hotkey
        // сериализованы), чтобы быстрый рестарт во время await не подсунул в reuse
        // превью уже НОВОЙ записи.
        let finalizingSession = recordingSession

        // Асинхронная транскрипция
        Task {
            // Гарантированное восстановление аудио окружения даже при ошибках
            defer {
                Task { @MainActor in
                    restoreAudioEnvironment()
                }
            }

            await performTranscription(audioData: audioData, finalizingSession: finalizingSession)
        }
    }

    /// Обработка аудио чанка для real-time транскрипции.
    /// ВАЖНО: chunk содержит ВСЁ накопленное аудио с начала записи (кумулятивный
    /// подход — модель видит полный контекст, качество не страдает).
    /// Общее изменяемое состояние трогаем только на MainActor — на отпускании
    /// решение о переиспользовании читает то же состояние и не должно ловить гонку.
    public func handleAudioChunk(_ chunk: [Float], epoch: Int) {
        Task { @MainActor in
            // Отбрасываем чанк, эмитированный предыдущей записью (epoch устарел):
            // его аудио не принадлежит текущей записи и не должно переиспользоваться.
            guard epoch == self.audioService.recordingEpoch else { return }

            // Пропускаем если уже идет обработка предыдущего чанка
            guard !self.isTranscribingChunk else { return }

            self.isTranscribingChunk = true
            let snapshotCount = chunk.count
            self.inFlightSnapshotCount = snapshotCount
            let session = self.recordingSession
            let chunkDuration = Float(chunk.count) / Float(AppConstants.Audio.whisperSampleRate)

            self.inFlightChunkTask = Task { [weak self] in
                guard let self = self else { return }
                var fullText = ""
                do {
                    // Быстрая транскрипция ВСЕГО накопленного аудио
                    fullText = try await self.whisperService.transcribeChunk(audioSamples: chunk)
                } catch {
                    LogManager.app.error("Ошибка транскрипции чанка: \(error.localizedDescription)")
                }

                // Снимаем флаг и публикуем результат ТОЛЬКО если запись не сменилась —
                // иначе поздний результат старой записи затрёт состояние новой.
                let stillCurrent = await MainActor.run { () -> Bool in
                    guard session == self.recordingSession else { return false }
                    self.isTranscribingChunk = false
                    return true
                }
                guard stillCurrent, !fullText.isEmpty else { return }

                await self.handleTranscribedChunk(fullText, duration: chunkDuration, snapshotCount: snapshotCount, session: session)
            }
        }
    }

    // MARK: - Private Methods - State Management

    /// Сброс состояния координатора
    private func resetState() {
        recordingSession += 1   // новая запись — инвалидирует превью предыдущей
        partialTranscriptionText = ""
        isTranscribingChunk = false
        lastTranscribedSampleCount = 0
        inFlightSnapshotCount = 0
        inFlightChunkTask?.cancel()
        inFlightChunkTask = nil
        audioService.clearBuffer()
    }

    /// Обработка транскрибированного чанка
    /// - Parameter snapshotCount: сколько сэмплов покрывает этот результат
    private func handleTranscribedChunk(_ text: String, duration: Float, snapshotCount: Int, session: Int) async {
        // Проверка на стоп-слова
        if userSettings.containsStopWord(text) {
            await handleStopWordDetected(session: session)
        } else {
            await updatePartialTranscription(text, duration: duration, snapshotCount: snapshotCount, session: session)
        }
    }

    /// Обработка обнаружения стоп-слова
    private func handleStopWordDetected(session: Int) async {
        LogManager.app.info("🛑 Обнаружено стоп-слово - сброс буфера")

        await MainActor.run {
            guard session == self.recordingSession else { return }  // запись сменилась
            // Стоп-слово отбрасывает накопленное аудио. Инвалидируем уже идущие и
            // очередные превью: новый session отбросит результат in-flight чанка, а
            // clearBuffer() бьёт recordingEpoch → очередные чанки прежнего сегмента
            // тоже отбрасываются. Иначе их текст мог бы быть переиспользован на отпускании.
            recordingSession += 1
            inFlightChunkTask?.cancel()
            inFlightChunkTask = nil
            inFlightSnapshotCount = 0
            // Сброс буфера и состояния
            audioService.clearBuffer()
            partialTranscriptionText = ""
            lastTranscribedSampleCount = 0
            floatingWindow.updatePartialTranscription("")
            floatingWindow.resetTimer()

            // Звуковой сигнал об отмене
            soundManager.play(.recordingStopped)
        }
    }

    /// Обновление частичной транскрипции в UI.
    /// partialTranscriptionText и lastTranscribedSampleCount пишутся ВМЕСТЕ на
    /// MainActor — чтобы решение о переиспользовании на отпускании видело
    /// согласованную пару (текст ↔ сколько сэмплов он покрывает).
    private func updatePartialTranscription(_ text: String, duration: Float, snapshotCount: Int, session: Int) async {
        await MainActor.run {
            guard session == self.recordingSession else { return }  // запись сменилась — отбрасываем
            // ЗАМЕНЯЕМ текст полностью (не накапливаем!), т.к. транскрибируем всё аудио заново
            partialTranscriptionText = text
            lastTranscribedSampleCount = snapshotCount
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

    /// Восстановление аудио окружения после транскрипции
    /// ВАЖНО: Вызывается ПОСЛЕ завершения транскрипции, а не сразу после остановки записи,
    /// чтобы предотвратить попадание кусочков музыки в конец аудио буфера
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

            // Бейдж движка: какой ускоритель задействован + скорость прошлой транскрипции
            floatingWindow.updateEngineInfo(
                engine: whisperService.accelerationSummary,
                averageRTF: whisperService.averageRTF,
                lastTime: whisperService.lastTranscriptionTime
            )

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
    private func performTranscription(audioData: [Float], finalizingSession: Int) async {
        let startTime = Date()

        // Проверка на тишину
        if silenceDetector.isSilence(audioData) {
            await handleSilenceDetected()
            return
        }

        // Решаем ДО ожидания, имеет ли смысл ждать спекулятивное превью:
        //  • в режиме повышения качества превью (быстрый greedy) использовать нельзя —
        //    нужен финальный проход с beam/threshold-настройками;
        //  • если хвост ПОСЛЕ будущего покрытия превью содержит речь, готовый текст
        //    всё равно не покроет конец фразы — ждать его бессмысленно (двойная задержка).
        let plan = await MainActor.run { () -> (task: Task<Void, Never>?, coverage: Int)? in
            // Запись успели сменить (быстрый рестарт) — превью уже не наше.
            guard finalizingSession == self.recordingSession else { return nil }
            guard !self.userSettings.useQualityEnhancement else { return nil }
            return (self.inFlightChunkTask, max(self.lastTranscribedSampleCount, self.inFlightSnapshotCount))
        }

        var reusedText: String? = nil
        if let plan = plan {
            let coverageStart = min(plan.coverage, audioData.count)
            let tail = Array(audioData[coverageStart...])
            // Ждём in-flight, только если ВЕСЬ хвост после его снапшота — тишина
            // (оконная проверка: одиночное среднее RMS спрятало бы короткое слово).
            if silenceDetector.isContinuousSilence(tail, rmsThreshold: silenceDetector.rmsThreshold) {
                await plan.task?.value
                reusedText = await reusablePartialTranscription(for: audioData, session: finalizingSession)
            }
        }

        let transcription: String
        if let cached = reusedText {
            // Хвост после последней транскрипции — тишина: готовый результат покрывает
            // всю речь, финальный проход не нужен.
            transcription = cached
            await MainActor.run { self.reuseHitCount += 1 }
            LogManager.transcription.success(
                "♻️ Переиспользуем превью (хвост = тишина), финальный проход пропущен",
                details: "reuse=\(reuseHitCount) final=\(finalPassCount)"
            )
        } else {
            do {
                await MainActor.run { self.finalPassCount += 1 }
                LogManager.transcription.begin("Финальная транскрипция", details: "reuse=\(reuseHitCount) final=\(finalPassCount)")
                transcription = try await whisperService.transcribe(audioSamples: audioData)
            } catch {
                await handleTranscriptionError(error)
                return
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let audioDuration = Double(audioData.count) / 16000.0
        LogManager.transcription.debug(
            "⏱️ post-release latency=\(String(format: "%.2f", duration))s, audio=\(String(format: "%.2f", audioDuration))s, avgRTF=\(String(format: "%.2f", whisperService.averageRTF))"
        )

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
    }

    /// Можно ли переиспользовать результат превью вместо финального прохода.
    /// Возвращает текст, только если хвост аудио после последней транскрипции —
    /// тишина (иначе мы потеряли бы последние слова, сказанные перед отпусканием).
    @MainActor
    private func reusablePartialTranscription(for audioData: [Float], session: Int) -> String? {
        // Превью принадлежит финализируемой записи? Иначе (рестарт во время await)
        // partialTranscriptionText — уже от новой записи, переиспользовать нельзя.
        guard session == recordingSession else { return nil }
        guard !partialTranscriptionText.isEmpty else { return nil }
        let start = min(lastTranscribedSampleCount, audioData.count)
        let tail = Array(audioData[start...])
        // НЕ используем isSilence: он считает любой хвост < 0.3с тишиной
        // (minSpeechDuration) и мог бы отбросить короткое последнее слово.
        // Оконная проверка тишины тем же порогом, что и финальная детекция речи
        // (любое окно с энергией → не переиспользуем, чтобы не терять тихие слова).
        guard silenceDetector.isContinuousSilence(tail, rmsThreshold: silenceDetector.rmsThreshold) else { return nil }
        return partialTranscriptionText
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
