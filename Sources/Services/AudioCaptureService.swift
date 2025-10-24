import AVFoundation
import Combine

/// Сервис для захвата аудио с микрофона
/// Использует AVAudioEngine для низколатентной записи в формате 16kHz mono
public class AudioCaptureService: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    @Published public var isRecording = false
    @Published public var permissionGranted = false

    public init() {
        print("AudioCaptureService: Инициализация")
    }

    /// Проверка разрешений на доступ к микрофону
    public func checkPermissions() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionGranted = true
            print("AudioCaptureService: Разрешение на микрофон уже получено")
            return true
        case .notDetermined:
            permissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
            if permissionGranted {
                print("AudioCaptureService: Разрешение на микрофон получено")
            } else {
                print("AudioCaptureService: Разрешение на микрофон отклонено")
            }
            return permissionGranted
        default:
            permissionGranted = false
            print("AudioCaptureService: Разрешение на микрофон отсутствует")
            return false
        }
    }

    /// Начать запись аудио
    public func startRecording() throws {
        guard permissionGranted else {
            throw AudioError.permissionDenied
        }

        print("AudioCaptureService: Начало записи")
        audioBuffer.removeAll()

        let inputNode = audioEngine.inputNode

        // Получаем нативный формат микрофона
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("AudioCaptureService: Нативный формат микрофона: \(inputFormat)")

        // Целевой формат 16kHz mono для Whisper
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioError.invalidFormat
        }

        // Создаём конвертер для преобразования формата
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioError.invalidFormat
        }

        // Установка tap с нативным форматом микрофона
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }

        try audioEngine.start()

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
    }

    /// Остановить запись и вернуть аудио данные
    public func stopRecording() -> [Float] {
        print("AudioCaptureService: Остановка записи")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }

        bufferLock.lock()
        defer { bufferLock.unlock() }

        let result = audioBuffer
        audioBuffer.removeAll()

        print("AudioCaptureService: Записано \(result.count) сэмплов (\(Float(result.count) / 16000.0) секунд)")
        return result
    }

    /// Обработка буфера аудио с конвертацией
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        // Вычисляем размер выходного буфера
        let inputFrameCount = buffer.frameLength
        let outputCapacity = AVAudioFrameCount(Double(inputFrameCount) * outputFormat.sampleRate / buffer.format.sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else {
            print("AudioCaptureService: Ошибка конвертации: \(error?.localizedDescription ?? "unknown")")
            return
        }

        // Извлекаем сконвертированные сэмплы
        guard let channelData = outputBuffer.floatChannelData else { return }
        let frameLength = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }

    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}

/// Ошибки аудио захвата
public enum AudioError: Error {
    case permissionDenied
    case invalidFormat
    case engineStartFailed

    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Отсутствует разрешение на доступ к микрофону"
        case .invalidFormat:
            return "Неверный формат аудио"
        case .engineStartFailed:
            return "Не удалось запустить аудио движок"
        }
    }
}
