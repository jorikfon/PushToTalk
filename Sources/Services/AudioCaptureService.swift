import AVFoundation
import Combine
import CoreAudio

/// Сервис для захвата аудио с микрофона
/// Использует AVAudioEngine для низколатентной записи в формате 16kHz mono
public class AudioCaptureService: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    @Published public var isRecording = false
    @Published public var permissionGranted = false

    // Callback для real-time обработки чанков (вызывается каждые N секунд)
    public var onAudioChunkReady: (([Float]) -> Void)?
    private let chunkDurationSeconds: Float = 2.0  // Размер чанка в секундах
    private var lastChunkProcessedAt: Int = 0  // Количество сэмплов на момент последней обработки

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

        // Устанавливаем выбранное пользователем устройство
        if let selectedDevice = AudioDeviceManager.shared.getSelectedDeviceOrDefault() {
            setAudioInputDevice(selectedDevice)
            LogManager.audio.info("Используем устройство: \(selectedDevice.name)")
        } else {
            LogManager.audio.warning("Не удалось получить аудио устройство, используем системное по умолчанию")
        }

        audioBuffer.removeAll()
        lastChunkProcessedAt = 0  // Сброс счетчика чанков
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

    /// Проверяет накопленное аудио и вызывает callback для обработки чанка
    /// ВАЖНО: Отправляет ВСЁ накопленное аудио с начала записи (кумулятивный подход)
    private func checkAndProcessChunk(currentBufferSize: Int) {
        let chunkSizeInSamples = Int(chunkDurationSeconds * 16000)  // 2 сек * 16000 Hz = 32000 сэмплов
        let samplesAccumulated = currentBufferSize - lastChunkProcessedAt

        // Если накопили достаточно для следующего интервала
        if samplesAccumulated >= chunkSizeInSamples {
            bufferLock.lock()
            // КУМУЛЯТИВНЫЙ ПОДХОД: Копируем ВСЁ аудио от начала до текущей позиции
            // Это даёт модели больше контекста и улучшает точность распознавания
            let cumulativeChunk = Array(audioBuffer[0..<currentBufferSize])
            lastChunkProcessedAt = currentBufferSize
            bufferLock.unlock()

            let chunkDuration = Float(cumulativeChunk.count) / 16000.0
            LogManager.audio.info("Кумулятивный чанк готов: \(cumulativeChunk.count) сэмплов (\(String(format: "%.2f", chunkDuration))s)")

            // Вызываем callback на главном потоке
            DispatchQueue.main.async { [weak self] in
                self?.onAudioChunkReady?(cumulativeChunk)
            }
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
