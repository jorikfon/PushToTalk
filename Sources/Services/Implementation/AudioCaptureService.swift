import AVFoundation
import Combine
import CoreAudio
import Accelerate

/// Сервис для захвата аудио с микрофона
/// Использует AVAudioEngine для низколатентной записи в формате 16kHz mono
public class AudioCaptureService: AudioCaptureServiceProtocol, ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    @Published public var isRecording = false
    @Published public var permissionGranted = false

    /// Номер текущей записи. Инкрементируется в startRecording(); проставляется
    /// каждому выдаваемому чанку, чтобы потребитель мог отбросить чанки,
    /// эмитированные предыдущей записью, но ещё не вычитанные из AsyncStream.
    public private(set) var recordingEpoch: Int = 0

    // MARK: - AsyncStream API

    /// Поток real-time аудио чанков. Каждый элемент помечен epoch — номером
    /// записи, в которой он был получен (для отбрасывания чанков прошлой записи).
    public var audioChunks: AsyncStream<(epoch: Int, samples: [Float])> {
        AsyncStream { continuation in
            // Сохраняем continuation для отправки чанков
            self.chunkContinuation = continuation

            // Cleanup при завершении stream
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.chunkContinuation = nil
            }
        }
    }

    // MARK: - Deprecated Callback API

    // Callback для real-time обработки чанков (вызывается каждые N секунд)
    public var onAudioChunkReady: (([Float]) -> Void)?

    // MARK: - Private Properties

    /// Интервал "safety net" для периодической выдачи чанка, если речь идёт без пауз.
    /// Основной триггер превью — детекция паузы (speech→silence), см. detectPauseAndEmit.
    private let chunkDurationSeconds: Float = 4.0
    private var lastChunkProcessedAt: Int = 0  // Количество сэмплов на момент последней обработки

    // MARK: - Pause detection (speech→silence) для раннего запуска транскрипции

    /// Длина хвостового окна для оценки тишины (секунды)
    private let pauseWindowSeconds: Float = 0.4
    /// RMS, выше которого считаем, что идёт речь (вход в состояние "говорит")
    private let speechRMSThreshold: Float = 0.01
    /// RMS, ниже которого считаем тишиной (выход → пауза); гистерезис относительно speech
    private let silenceRMSThreshold: Float = 0.004
    /// Минимум новых сэмплов между выдачами чанка, чтобы не спамить (0.5с)
    private let minSamplesBetweenEmits: Int = 8000
    /// Был ли зафиксирован факт речи (для детекции перехода речь→тишина)
    private var wasSpeaking = false

    /// Continuation для AsyncStream аудио чанков
    private var chunkContinuation: AsyncStream<(epoch: Int, samples: [Float])>.Continuation?

    // MARK: - Initialization

    public init() {
        LogManager.audio.info("Инициализация AudioCaptureService")
    }

    /// Проверка разрешений на доступ к микрофону
    public func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
            LogManager.audio.success("Разрешение на микрофон", details: "Уже получено")
            return true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
            if permissionGranted {
                LogManager.audio.success("Разрешение на микрофон", details: "Получено от пользователя")
            } else {
                LogManager.audio.failure("Разрешение на микрофон", message: "Отклонено пользователем")
            }
            return permissionGranted
        default:
            permissionGranted = false
            LogManager.audio.failure("Разрешение на микрофон", message: "Отсутствует или ограничено")
            return false
        }
    }

    /// Начать запись аудио
    public func startRecording() throws {
        LogManager.audio.begin("Запись аудио")

        guard permissionGranted else {
            LogManager.audio.failure("Запись аудио", message: "Разрешение на микрофон НЕ предоставлено")
            throw AudioError.permissionDenied
        }
        LogManager.audio.debug("Разрешение на микрофон проверено")

        // Проверяем, не запущен ли уже engine
        if audioEngine.isRunning {
            LogManager.audio.info("Audio engine уже запущен, останавливаем")
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // TODO: Устанавливаем выбранное пользователем устройство через DI
        // Временно закомментировано для устранения singleton зависимости
        // Будет восстановлено в следующем этапе через ServiceContainer
        // if let selectedDevice = audioDeviceManager?.getSelectedDeviceOrDefault() {
        //     setAudioInputDevice(selectedDevice)
        //     LogManager.audio.info("Используем устройство: \(selectedDevice.name)")
        // } else {
        //     LogManager.audio.warning("Не удалось получить аудио устройство, используем системное по умолчанию")
        // }

        audioBuffer.removeAll()
        lastChunkProcessedAt = 0  // Сброс счетчика чанков
        wasSpeaking = false       // Сброс детектора паузы
        recordingEpoch += 1       // Новая запись — метка для отбрасывания старых чанков
        LogManager.audio.debug("Буфер очищен")

        let inputNode = audioEngine.inputNode
        LogManager.audio.debug("Input node получен")

        // Получаем нативный формат микрофона
        let inputFormat = inputNode.inputFormat(forBus: 0)
        LogManager.audio.debug("Нативный формат микрофона: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch, format=\(inputFormat.commonFormat.rawValue)")

        // Предупреждение если формат выглядит невалидным (но продолжаем попытку)
        if inputFormat.sampleRate == 0 || inputFormat.channelCount == 0 {
            LogManager.audio.error("Формат микрофона имеет нулевые значения, но продолжаем")
        }

        // Целевой формат 16kHz mono для Whisper
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            LogManager.audio.failure("Создание формата", message: "Не удалось создать целевой формат 16kHz mono")
            throw AudioError.invalidFormat
        }
        LogManager.audio.debug("Целевой формат создан (16kHz mono)")

        // Создаём конвертер для преобразования формата
        LogManager.audio.debug("Создаём конвертер: \(inputFormat.sampleRate)Hz/\(inputFormat.channelCount)ch → 16000Hz/1ch")
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            LogManager.audio.failure("Создание конвертера", message: "Входной: \(inputFormat.sampleRate)Hz/\(inputFormat.channelCount)ch, Выходной: 16000Hz/1ch")
            throw AudioError.invalidFormat
        }
        LogManager.audio.debug("Аудио конвертер создан")

        // Установка tap с нативным форматом микрофона
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
        LogManager.audio.debug("Tap установлен на input node (buffer size: 4096)")

        do {
            try audioEngine.start()
            LogManager.audio.debug("Audio engine запущен")
        } catch {
            LogManager.audio.failure("Запуск audio engine", error: error)
            // Убираем tap если не удалось запустить engine
            inputNode.removeTap(onBus: 0)
            throw AudioError.engineStartFailed(error.localizedDescription)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
        LogManager.audio.success("Запись аудио активна")
    }

    /// Остановить запись и вернуть аудио данные
    public func stopRecording() -> [Float] {
        LogManager.audio.begin("Остановка записи")

        audioEngine.stop()
        LogManager.audio.debug("Audio engine остановлен")

        audioEngine.inputNode.removeTap(onBus: 0)
        LogManager.audio.debug("Tap удален")

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }

        bufferLock.lock()
        defer { bufferLock.unlock() }

        let result = audioBuffer
        audioBuffer.removeAll()

        let durationSeconds = Float(result.count) / 16000.0
        LogManager.audio.info("Статистика записи: \(result.count) сэмплов, \(String(format: "%.2f", durationSeconds))s")

        if result.isEmpty {
            LogManager.audio.error("Записанный буфер ПУСТОЙ")
        } else {
            LogManager.audio.success("Остановка записи", details: "\(result.count) сэмплов")
        }

        return result
    }

    /// Очистить буфер записи (для команды "отмена")
    public func clearBuffer() {
        LogManager.audio.info("Очистка буфера аудио (команда отмена)")

        bufferLock.lock()
        audioBuffer.removeAll()
        lastChunkProcessedAt = 0
        wasSpeaking = false
        bufferLock.unlock()

        LogManager.audio.success("Буфер очищен", details: "Запись начата с начала")
    }

    /// Обработка буфера аудио с конвертацией
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        // Вычисляем размер выходного буфера
        let inputFrameCount = buffer.frameLength
        let outputCapacity = AVAudioFrameCount(Double(inputFrameCount) * outputFormat.sampleRate / buffer.format.sampleRate)

        // Логируем каждый 10-й буфер чтобы не спамить
        if audioBuffer.count % 16000 < 4096 {  // Примерно раз в секунду
            LogManager.audio.debug("Обработка буфера: вход=\(inputFrameCount), выход=\(outputCapacity)")
        }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            LogManager.audio.error("Не удалось создать выходной буфер")
            return
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else {
            LogManager.audio.failure("Конвертация аудио", message: error?.localizedDescription ?? "unknown")
            return
        }

        // Извлекаем сконвертированные сэмплы
        guard let channelData = outputBuffer.floatChannelData else {
            LogManager.audio.error("Нет данных в канале после конвертации")
            return
        }
        let frameLength = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        bufferLock.lock()
        let oldCount = audioBuffer.count
        audioBuffer.append(contentsOf: samples)
        let newCount = audioBuffer.count
        bufferLock.unlock()

        // Логируем каждый 10-й буфер
        if oldCount % 16000 < 4096 {
            LogManager.audio.debug("Добавлено \(samples.count) сэмплов, всего: \(newCount) (\(String(format: "%.2f", Float(newCount) / 16000.0))s)")
        }

        // Проверяем, нужно ли обработать очередной чанк
        checkAndProcessChunk(currentBufferSize: newCount)
    }

    /// Проверяет накопленное аудио и решает, когда выдать чанк на транскрипцию.
    /// Приоритет — детекция паузы (speech→silence): транскрипция стартует в момент,
    /// когда пользователь замолчал, чтобы успеть к отпусканию hotkey (overlap+reuse).
    /// Периодическая выдача каждые `chunkDurationSeconds` — лишь safety net для
    /// длинной речи без пауз.
    private func checkAndProcessChunk(currentBufferSize: Int) {
        // 1. Быстрый путь: конец речи (пауза)
        detectPauseAndEmit(currentBufferSize: currentBufferSize)

        // 2. Safety net: давно не выдавали — выдадим по интервалу
        let chunkSizeInSamples = Int(chunkDurationSeconds * 16000)
        let samplesAccumulated = currentBufferSize - lastChunkProcessedAt
        if samplesAccumulated >= chunkSizeInSamples {
            emitCumulativeChunk(currentBufferSize: currentBufferSize, reason: "interval")
        }
    }

    /// Детекция перехода речь→тишина по хвостовому окну RMS (вызывается ~каждые
    /// ~256мс из tap-колбэка). При обнаружении паузы выдаёт кумулятивный буфер,
    /// чтобы транскрипция началась немедленно, а не на границе периодического чанка.
    private func detectPauseAndEmit(currentBufferSize: Int) {
        let windowSize = Int(pauseWindowSeconds * 16000)

        // Длину берём под локом по факту: буфер мог быть очищен (stop/clearBuffer)
        // между захватом currentBufferSize и этим моментом — иначе слайс упадёт.
        bufferLock.lock()
        let count = audioBuffer.count
        guard count >= windowSize else { bufferLock.unlock(); return }
        let tail = Array(audioBuffer[(count - windowSize)..<count])
        bufferLock.unlock()

        var rms: Float = 0
        vDSP_rmsqv(tail, 1, &rms, vDSP_Length(tail.count))

        // Громко → запоминаем, что речь была
        if rms > speechRMSThreshold {
            wasSpeaking = true
            return
        }

        // Тихо после речи → пауза: запускаем транскрипцию накопленного
        if wasSpeaking && rms < silenceRMSThreshold {
            let samplesSinceLast = count - lastChunkProcessedAt
            guard samplesSinceLast >= minSamplesBetweenEmits else { return }
            wasSpeaking = false
            emitCumulativeChunk(currentBufferSize: count, reason: "pause")
        }
    }

    /// Выдаёт ВЕСЬ накопленный буфер (кумулятивный подход — модель видит полный
    /// контекст, качество не страдает) в AsyncStream и deprecated-callback.
    private func emitCumulativeChunk(currentBufferSize: Int, reason: String) {
        bufferLock.lock()
        // Кламп по фактической длине: буфер мог быть очищен между вызовами.
        let count = min(currentBufferSize, audioBuffer.count)
        guard count > 0 else { bufferLock.unlock(); return }
        let cumulativeChunk = Array(audioBuffer[0..<count])
        lastChunkProcessedAt = count
        let epoch = recordingEpoch
        bufferLock.unlock()

        let chunkDuration = Float(cumulativeChunk.count) / 16000.0
        LogManager.audio.info("Кумулятивный чанк [\(reason)]: \(cumulativeChunk.count) сэмплов (\(String(format: "%.2f", chunkDuration))s)")

        // Отправляем в AsyncStream с меткой записи (epoch)
        chunkContinuation?.yield((epoch: epoch, samples: cumulativeChunk))

        // Вызываем deprecated callback на главном потоке для backwards compatibility
        DispatchQueue.main.async { [weak self] in
            self?.onAudioChunkReady?(cumulativeChunk)
        }
    }

    /// Установить аудио устройство для записи
    private func setAudioInputDevice(_ device: AudioDevice) {
        #if os(macOS)
        // На macOS используем CoreAudio для установки входного устройства
        var deviceUID = device.uid as CFString
        var selector = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Ищем устройство по UID
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var translationAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &translationAddress,
            UInt32(MemoryLayout<CFString>.size),
            &deviceUID,
            &propertySize,
            &deviceID
        )

        if status == noErr {
            LogManager.audio.debug("Найдено устройство с ID: \(deviceID)")

            // Устанавливаем как входное устройство по умолчанию
            var mutableDeviceID = deviceID
            let setStatus = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &selector,
                0,
                nil,
                propertySize,
                &mutableDeviceID
            )

            if setStatus == noErr {
                LogManager.audio.success("Установлено входное устройство", details: device.name)
            } else {
                LogManager.audio.error("Не удалось установить входное устройство: OSStatus \(setStatus)")
            }
        } else {
            LogManager.audio.error("Не удалось найти устройство по UID: OSStatus \(status)")
        }
        #endif
    }

    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        LogManager.audio.info("AudioCaptureService деинициализирован")
    }
}

/// Ошибки аудио захвата
public enum AudioError: Error {
    case permissionDenied
    case invalidFormat
    case engineStartFailed(String)
    case noInputDevice

    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Отсутствует разрешение на доступ к микрофону. Проверьте Settings > Privacy & Security > Microphone"
        case .invalidFormat:
            return "Неверный формат аудио"
        case .engineStartFailed(let details):
            return "Не удалось запустить аудио движок: \(details)"
        case .noInputDevice:
            return "Микрофон не найден. Проверьте подключение микрофона или выберите другой входной источник в системных настройках"
        }
    }
}
