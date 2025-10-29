import Foundation
import AVFoundation
import PushToTalkCore

/// Структура для хранения диалога с разделением по дикторам
public struct DialogueTranscription {
    public struct Turn {
        public let speaker: Speaker
        public let text: String

        public enum Speaker {
            case left   // Левый канал (Speaker 1)
            case right  // Правый канал (Speaker 2)

            var displayName: String {
                switch self {
                case .left: return "Speaker 1"
                case .right: return "Speaker 2"
                }
            }
        }
    }

    public let turns: [Turn]
    public let isStereo: Bool

    /// Форматирует диалог как текст
    public func formatted() -> String {
        if !isStereo || turns.isEmpty {
            return turns.first?.text ?? ""
        }

        return turns.map { turn in
            "[\(turn.speaker.displayName)]: \(turn.text)"
        }.joined(separator: "\n\n")
    }
}

/// Сервис для транскрипции audio/video файлов
/// Загружает файл, конвертирует в формат WhisperKit и транскрибирует
public class FileTranscriptionService {
    private let whisperService: WhisperService

    public init(whisperService: WhisperService) {
        self.whisperService = whisperService
    }

    /// Транскрибирует аудио/видео файл с поддержкой стерео разделения
    /// - Parameter url: URL файла для транскрипции
    /// - Returns: Диалог с разделением по дикторам (если стерео)
    /// - Throws: Ошибки загрузки или транскрипции
    public func transcribeFileWithDialogue(at url: URL) async throws -> DialogueTranscription {
        LogManager.app.begin("Транскрипция файла с определением дикторов: \(url.lastPathComponent)")

        // 1. Проверяем, стерео ли файл
        let channelCount = try await getChannelCount(from: url)
        LogManager.app.info("Обнаружено каналов: \(channelCount)")

        if channelCount == 2 {
            // Стерео: разделяем каналы и транскрибируем отдельно
            return try await transcribeStereoAsDialogue(url: url)
        } else {
            // Моно: обычная транскрипция
            let text = try await transcribeFile(at: url)
            return DialogueTranscription(
                turns: [DialogueTranscription.Turn(speaker: .left, text: text)],
                isStereo: false
            )
        }
    }

    /// Транскрибирует аудио/видео файл (обычный режим)
    /// - Parameter url: URL файла для транскрипции
    /// - Returns: Текст транскрипции
    /// - Throws: Ошибки загрузки или транскрипции
    public func transcribeFile(at url: URL) async throws -> String {
        LogManager.app.begin("Транскрипция файла: \(url.lastPathComponent)")

        // 1. Загружаем аудио из файла
        let audioSamples = try await loadAudio(from: url)

        // 2. Проверяем на тишину
        if SilenceDetector.shared.isSilence(audioSamples) {
            LogManager.app.info("🔇 Файл содержит только тишину")
            throw FileTranscriptionError.silenceDetected
        }

        // 3. Транскрибируем
        let transcription = try await whisperService.transcribe(audioSamples: audioSamples)

        if transcription.isEmpty {
            throw FileTranscriptionError.emptyTranscription
        }

        LogManager.app.success("Транскрипция файла завершена: \(transcription.count) символов")
        return transcription
    }

    /// Загружает аудио из файла и конвертирует в формат WhisperKit (16kHz mono Float32)
    /// - Parameter url: URL файла
    /// - Returns: Массив audio samples
    /// - Throws: Ошибки загрузки или конвертации
    private func loadAudio(from url: URL) async throws -> [Float] {
        let asset = AVAsset(url: url)

        // Проверяем, что файл содержит audio track
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            LogManager.app.failure("Файл не содержит audio track", error: FileTranscriptionError.noAudioTrack)
            throw FileTranscriptionError.noAudioTrack
        }

        // Создаем reader для чтения аудио
        let reader = try AVAssetReader(asset: asset)

        // Настройки вывода: 16kHz, mono, Linear PCM Float32
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            LogManager.app.failure("Не удалось начать чтение файла", error: FileTranscriptionError.readError)
            throw FileTranscriptionError.readError
        }

        var audioSamples: [Float] = []

        // Читаем все sample buffers
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)

                _ = data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
                }

                // Конвертируем Data в [Float]
                let floatArray = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
                    let floatPtr = ptr.bindMemory(to: Float.self)
                    return Array(floatPtr)
                }

                audioSamples.append(contentsOf: floatArray)
            }
        }

        reader.cancelReading()

        let durationSeconds = Float(audioSamples.count) / 16000.0
        LogManager.app.success("Файл загружен: \(audioSamples.count) samples, \(String(format: "%.1f", durationSeconds))s")

        // Проверяем максимальную длительность (60 минут = 3600s)
        let maxDuration: Float = 3600.0
        if durationSeconds > maxDuration {
            LogManager.app.warning("Файл слишком длинный (\(String(format: "%.0f", durationSeconds))s), обрезаем до \(String(format: "%.0f", maxDuration))s")
            let maxSamples = Int(maxDuration * 16000.0)
            return Array(audioSamples.prefix(maxSamples))
        }

        return audioSamples
    }

    /// Получает количество аудио каналов в файле
    private func getChannelCount(from url: URL) async throws -> Int {
        let asset = AVAsset(url: url)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw FileTranscriptionError.noAudioTrack
        }

        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            return 1 // По умолчанию моно
        }

        if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
            return Int(audioStreamBasicDescription.pointee.mChannelsPerFrame)
        }

        return 1
    }

    /// Транскрибирует стерео файл как диалог (левый и правый каналы отдельно)
    private func transcribeStereoAsDialogue(url: URL) async throws -> DialogueTranscription {
        LogManager.app.info("🎧 Стерео режим: разделяем каналы для определения дикторов")

        // 1. Загружаем стерео аудио
        let stereoSamples = try await loadAudioStereo(from: url)

        // 2. Разделяем на левый и правый каналы
        let leftChannel = extractChannel(from: stereoSamples, channel: 0)
        let rightChannel = extractChannel(from: stereoSamples, channel: 1)

        // 3. Транскрибируем каждый канал отдельно
        LogManager.app.info("Транскрибируем левый канал (Speaker 1)...")
        let leftText = try await whisperService.transcribe(audioSamples: leftChannel)

        LogManager.app.info("Транскрибируем правый канал (Speaker 2)...")
        let rightText = try await whisperService.transcribe(audioSamples: rightChannel)

        // 4. Создаём диалог с полными текстами от каждого диктора
        var turns: [DialogueTranscription.Turn] = []

        // Добавляем все реплики левого канала (Speaker 1)
        if !leftText.isEmpty {
            turns.append(DialogueTranscription.Turn(speaker: .left, text: leftText))
        }

        // Добавляем все реплики правого канала (Speaker 2)
        if !rightText.isEmpty {
            turns.append(DialogueTranscription.Turn(speaker: .right, text: rightText))
        }

        LogManager.app.success("Стерео транскрипция завершена: левый канал (\(leftText.count) символов), правый канал (\(rightText.count) символов)")

        return DialogueTranscription(turns: turns, isStereo: true)
    }

    /// Загружает стерео аудио (сохраняя оба канала)
    private func loadAudioStereo(from url: URL) async throws -> [[Float]] {
        let asset = AVAsset(url: url)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw FileTranscriptionError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)

        // Настройки вывода: 16kHz, STEREO (2 channels), Linear PCM Float32
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 2,  // Стерео!
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false  // Interleaved: L, R, L, R, ...
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)

        guard reader.startReading() else {
            throw FileTranscriptionError.readError
        }

        var interleavedSamples: [Float] = []

        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                let length = CMBlockBufferGetDataLength(blockBuffer)
                var data = Data(count: length)

                _ = data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
                }

                let floatArray = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Float] in
                    let floatPtr = ptr.bindMemory(to: Float.self)
                    return Array(floatPtr)
                }

                interleavedSamples.append(contentsOf: floatArray)
            }
        }

        reader.cancelReading()

        // Возвращаем как массив из двух каналов (пока interleaved)
        return [interleavedSamples]
    }

    /// Извлекает один канал из interleaved стерео
    private func extractChannel(from stereoData: [[Float]], channel: Int) -> [Float] {
        guard let interleavedSamples = stereoData.first else { return [] }

        var channelSamples: [Float] = []
        channelSamples.reserveCapacity(interleavedSamples.count / 2)

        // Interleaved format: L, R, L, R, L, R, ...
        // channel 0 = left (indices 0, 2, 4, ...)
        // channel 1 = right (indices 1, 3, 5, ...)
        stride(from: channel, to: interleavedSamples.count, by: 2).forEach { index in
            channelSamples.append(interleavedSamples[index])
        }

        let durationSeconds = Float(channelSamples.count) / 16000.0
        LogManager.app.info("Канал \(channel): \(channelSamples.count) samples, \(String(format: "%.1f", durationSeconds))s")

        return channelSamples
    }

}

/// Ошибки транскрипции файлов
enum FileTranscriptionError: LocalizedError {
    case noAudioTrack
    case readError
    case silenceDetected
    case emptyTranscription
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "File does not contain an audio track"
        case .readError:
            return "Failed to read audio file"
        case .silenceDetected:
            return "File contains only silence"
        case .emptyTranscription:
            return "Transcription resulted in empty text"
        case .fileTooLarge:
            return "File is too large (max 60 minutes)"
        }
    }
}
