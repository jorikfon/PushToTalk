import Foundation
import AVFoundation
import PushToTalkCore

/// Структура для хранения диалога с разделением по дикторам и временными метками
public struct DialogueTranscription {
    public struct Turn: Identifiable {
        public let id = UUID()  // Уникальный идентификатор для SwiftUI
        public let speaker: Speaker
        public let text: String
        public let startTime: TimeInterval  // Время начала реплики в секундах
        public let endTime: TimeInterval    // Время окончания реплики в секундах

        public enum Speaker {
            case left   // Левый канал (Speaker 1)
            case right  // Правый канал (Speaker 2)

            public var displayName: String {
                switch self {
                case .left: return "Speaker 1"
                case .right: return "Speaker 2"
                }
            }

            public var color: String {
                switch self {
                case .left: return "blue"
                case .right: return "orange"
                }
            }
        }

        public var duration: TimeInterval {
            return endTime - startTime
        }

        public init(speaker: Speaker, text: String, startTime: TimeInterval, endTime: TimeInterval) {
            self.speaker = speaker
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    public let turns: [Turn]
    public let isStereo: Bool
    public let totalDuration: TimeInterval  // Общая длительность диалога

    public init(turns: [Turn], isStereo: Bool, totalDuration: TimeInterval = 0) {
        self.turns = turns
        self.isStereo = isStereo
        self.totalDuration = totalDuration
    }

    /// Возвращает реплики, отсортированные по времени (для timeline)
    public var sortedByTime: [Turn] {
        return turns.sorted { $0.startTime < $1.startTime }
    }

    /// Форматирует диалог как текст с временными метками
    public func formatted() -> String {
        if !isStereo || turns.isEmpty {
            return turns.first?.text ?? ""
        }

        return sortedByTime.map { turn in
            let timestamp = formatTimestamp(turn.startTime)
            return "[\(timestamp)] \(turn.speaker.displayName): \(turn.text)"
        }.joined(separator: "\n\n")
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, secs, millis)
    }
}

/// Сервис для транскрипции audio/video файлов
/// Загружает файл, конвертирует в формат WhisperKit и транскрибирует
public class FileTranscriptionService {

    /// Режим транскрипции
    public enum TranscriptionMode {
        case vad        // Использовать Voice Activity Detection (лучше для чистого аудио)
        case batch      // Пакетная транскрипция фиксированными чанками (лучше для низкого качества)
    }

    private let whisperService: WhisperService
    private var batchService: BatchTranscriptionService?

    /// Текущий режим транскрипции
    public var mode: TranscriptionMode = .batch  // По умолчанию batch для телефонного аудио

    /// Callback для обновления промежуточных результатов (прогресс и реплики)
    public var onProgressUpdate: ((String, Double, DialogueTranscription?) -> Void)?

    public init(whisperService: WhisperService) {
        self.whisperService = whisperService
        self.batchService = BatchTranscriptionService(
            whisperService: whisperService,
            parameters: .lowQuality
        )
    }

    /// Транскрибирует аудио/видео файл с поддержкой стерео разделения
    /// - Parameter url: URL файла для транскрипции
    /// - Returns: Диалог с разделением по дикторам (если стерео)
    /// - Throws: Ошибки загрузки или транскрипции
    public func transcribeFileWithDialogue(at url: URL) async throws -> DialogueTranscription {
        LogManager.app.begin("Транскрипция файла с определением дикторов: \(url.lastPathComponent)")
        LogManager.app.info("Режим транскрипции: \(self.mode == .batch ? "BATCH" : "VAD")")

        // Используем batch режим, если выбран
        if mode == .batch {
            guard let batchService = batchService else {
                throw NSError(domain: "FileTranscriptionService", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "BatchTranscriptionService не инициализирован"])
            }

            // Пробрасываем callback в batchService
            batchService.onProgressUpdate = onProgressUpdate

            return try await batchService.transcribe(url: url)
        }

        // VAD режим (оригинальный код)
        // 1. Проверяем, стерео ли файл
        let channelCount = try await getChannelCount(from: url)
        LogManager.app.info("Обнаружено каналов: \(channelCount)")

        if channelCount == 2 {
            // Стерео: разделяем каналы и транскрибируем отдельно
            return try await transcribeStereoAsDialogue(url: url)
        } else {
            // Моно: обычная транскрипция
            let audioSamples = try await loadAudio(from: url)
            let totalDuration = TimeInterval(audioSamples.count) / 16000.0
            let text = try await whisperService.transcribe(audioSamples: audioSamples)

            LogManager.app.info("Моно транскрипция завершена: \(text.count) символов")

            let dialogue = DialogueTranscription(
                turns: [DialogueTranscription.Turn(
                    speaker: .left,
                    text: text,
                    startTime: 0,
                    endTime: totalDuration
                )],
                isStereo: false,
                totalDuration: totalDuration
            )

            // Вызываем callback для моно файлов тоже
            onProgressUpdate?(url.lastPathComponent, 1.0, dialogue)

            return dialogue
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

        // Ограничение убрано - поддерживаем файлы любой длительности
        // Транскрипция будет происходить по сегментам через VAD

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

        // 3. Определяем общую длительность
        let totalDuration = TimeInterval(leftChannel.count) / 16000.0

        // 4. Используем VAD для определения сегментов речи в каждом канале
        // Используем lowQuality параметры для лучшего распознавания телефонного аудио
        let vad = VoiceActivityDetector(parameters: .lowQuality)

        LogManager.app.info("🎤 VAD: анализ левого канала...")
        let leftSegments = vad.detectSpeechSegments(in: leftChannel)
        LogManager.app.info("Найдено \(leftSegments.count) сегментов речи в левом канале")

        LogManager.app.info("🎤 VAD: анализ правого канала...")
        let rightSegments = vad.detectSpeechSegments(in: rightChannel)
        LogManager.app.info("Найдено \(rightSegments.count) сегментов речи в правом канале")

        // 5. Транскрибируем каждый сегмент отдельно
        var turns: [DialogueTranscription.Turn] = []
        let totalSegments = leftSegments.count + rightSegments.count
        var processedSegments = 0

        // Транскрибируем левый канал (Speaker 1)
        for segment in leftSegments {
            let segmentAudio = vad.extractAudio(for: segment, from: leftChannel)

            if !SilenceDetector.shared.isSilence(segmentAudio) {
                LogManager.app.info("Транскрибируем Speaker 1: \(String(format: "%.1f", segment.startTime))s - \(String(format: "%.1f", segment.endTime))s")
                let text = try await whisperService.transcribe(audioSamples: segmentAudio)

                if !text.isEmpty {
                    turns.append(DialogueTranscription.Turn(
                        speaker: .left,
                        text: text,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    ))

                    // Обновляем прогресс после каждой реплики
                    processedSegments += 1
                    let progress = Double(processedSegments) / Double(totalSegments)
                    let partialDialogue = DialogueTranscription(turns: turns, isStereo: true, totalDuration: totalDuration)
                    LogManager.app.debug("Обновление прогресса: \(processedSegments)/\(totalSegments), turns: \(turns.count)")
                    onProgressUpdate?(url.lastPathComponent, progress, partialDialogue)
                } else {
                    LogManager.app.warning("Speaker 1: пустой текст для сегмента \(String(format: "%.1f", segment.startTime))s")
                }
            }
        }

        // Транскрибируем правый канал (Speaker 2)
        for segment in rightSegments {
            let segmentAudio = vad.extractAudio(for: segment, from: rightChannel)

            if !SilenceDetector.shared.isSilence(segmentAudio) {
                LogManager.app.info("Транскрибируем Speaker 2: \(String(format: "%.1f", segment.startTime))s - \(String(format: "%.1f", segment.endTime))s")
                let text = try await whisperService.transcribe(audioSamples: segmentAudio)

                if !text.isEmpty {
                    turns.append(DialogueTranscription.Turn(
                        speaker: .right,
                        text: text,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    ))

                    // Обновляем прогресс после каждой реплики
                    processedSegments += 1
                    let progress = Double(processedSegments) / Double(totalSegments)
                    let partialDialogue = DialogueTranscription(turns: turns, isStereo: true, totalDuration: totalDuration)
                    LogManager.app.debug("Обновление прогресса: \(processedSegments)/\(totalSegments), turns: \(turns.count)")
                    onProgressUpdate?(url.lastPathComponent, progress, partialDialogue)
                } else {
                    LogManager.app.warning("Speaker 2: пустой текст для сегмента \(String(format: "%.1f", segment.startTime))s")
                }
            }
        }

        LogManager.app.success("Стерео транскрипция завершена: \(turns.count) реплик (\(leftSegments.count) левых, \(rightSegments.count) правых)")

        return DialogueTranscription(turns: turns, isStereo: true, totalDuration: totalDuration)
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
