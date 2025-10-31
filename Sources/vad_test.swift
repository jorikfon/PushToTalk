import Foundation
import AVFoundation
import Accelerate
import PushToTalkCore

/// Консольный инструмент для тестирования и отладки алгоритмов Voice Activity Detection
/// Использование: .build/debug/VADTest <путь_к_аудио_файлу> [параметры]
@main
struct VADTest {
    static func main() async {
        print("🎙️ VAD Test Tool - Тестирование алгоритмов определения речи\n")

        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            return
        }

        let filePath = args[1]
        let url = URL(fileURLWithPath: filePath)

        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ Файл не найден: \(filePath)")
            return
        }

        print("📂 Загрузка файла: \(url.lastPathComponent)")

        do {
            // Загружаем аудио
            let (audioSamples, sampleRate, channelCount, duration) = try await loadAudioFile(url)

            print("✅ Файл загружен:")
            print("   • Sample Rate: \(Int(sampleRate)) Hz")
            print("   • Channels: \(channelCount)")
            print("   • Duration: \(formatDuration(duration))")
            print("   • Samples: \(audioSamples.count)")
            print()

            // Вычисляем общую статистику
            printAudioStats(audioSamples)

            // Тестируем разные параметры VAD
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🔬 Тестирование алгоритмов VAD\n")

            // 1. Default параметры
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "Default (стандартный)",
                parameters: .default
            )

            // 2. Low Quality параметры
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "Low Quality (телефонное аудио)",
                parameters: .lowQuality
            )

            // 3. High Quality параметры
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "High Quality (чистое аудио)",
                parameters: .highQuality
            )

            // 4. Very Sensitive (очень чувствительный)
            let verySensitive = VADParameters(
                windowSize: 0.05,
                minSpeechDuration: 0.2,
                minSilenceDuration: 0.3,
                rmsThreshold: 0.005  // Очень низкий порог
            )
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "Very Sensitive (очень чувствительный)",
                parameters: verySensitive
            )

            // 5. Aggressive (агрессивное разбиение)
            let aggressive = VADParameters(
                windowSize: 0.02,
                minSpeechDuration: 0.1,
                minSilenceDuration: 0.1,
                rmsThreshold: 0.01
            )
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "Aggressive (агрессивное разбиение)",
                parameters: aggressive
            )

            // 6. Conservative (консервативное - длинные сегменты)
            let conservative = VADParameters(
                windowSize: 0.1,
                minSpeechDuration: 1.0,
                minSilenceDuration: 1.0,
                rmsThreshold: 0.03
            )
            testVADWithParameters(
                audioSamples: audioSamples,
                name: "Conservative (длинные сегменты)",
                parameters: conservative
            )

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🚀 Продвинутые алгоритмы VAD\n")

            // 7. Adaptive VAD (адаптивный порог + ZCR)
            testAdaptiveVAD(
                audioSamples: audioSamples,
                name: "Adaptive VAD - Default",
                parameters: .default
            )

            testAdaptiveVAD(
                audioSamples: audioSamples,
                name: "Adaptive VAD - Low Quality",
                parameters: .lowQuality
            )

            testAdaptiveVAD(
                audioSamples: audioSamples,
                name: "Adaptive VAD - Aggressive",
                parameters: .aggressive
            )

            // 8. Spectral VAD (частотный анализ)
            testSpectralVAD(
                audioSamples: audioSamples,
                name: "Spectral VAD - Default",
                parameters: .default
            )

            testSpectralVAD(
                audioSamples: audioSamples,
                name: "Spectral VAD - Telephone",
                parameters: .telephone
            )

            testSpectralVAD(
                audioSamples: audioSamples,
                name: "Spectral VAD - Wideband",
                parameters: .wideband
            )

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("\n💡 Рекомендации:")
            print("   • Если сегментов слишком мало → используйте Very Sensitive или Aggressive")
            print("   • Если сегментов слишком много → используйте Conservative")
            print("   • Для телефонного аудио → используйте Low Quality")
            print("   • Для чистого аудио → используйте High Quality")

        } catch {
            print("❌ Ошибка: \(error.localizedDescription)")
        }
    }

    /// Тестирует VAD с заданными параметрами и выводит статистику
    static func testVADWithParameters(
        audioSamples: [Float],
        name: String,
        parameters: VADParameters
    ) {
        print("─────────────────────────────────────────────────────────")
        print("📊 \(name)")
        print("   Параметры:")
        print("   • Window Size: \(Int(parameters.windowSize * 1000))ms")
        print("   • Min Speech: \(Int(parameters.minSpeechDuration * 1000))ms")
        print("   • Min Silence: \(Int(parameters.minSilenceDuration * 1000))ms")
        print("   • RMS Threshold: \(String(format: "%.4f", parameters.rmsThreshold))")
        print()

        let vad = VoiceActivityDetector(parameters: parameters)
        let segments = vad.detectSpeechSegments(in: audioSamples)

        print("   Результат: \(segments.count) сегментов")

        if segments.isEmpty {
            print("   ⚠️ Сегментов не найдено!")
            print()
            return
        }

        // Статистика по сегментам
        let totalSpeechDuration = segments.reduce(0.0) { $0 + $1.duration }
        let avgDuration = totalSpeechDuration / Double(segments.count)
        let minDuration = segments.map(\.duration).min() ?? 0
        let maxDuration = segments.map(\.duration).max() ?? 0

        print("   • Общая длительность речи: \(formatDuration(totalSpeechDuration))")
        print("   • Средняя длительность сегмента: \(formatDuration(avgDuration))")
        print("   • Минимальная: \(formatDuration(minDuration))")
        print("   • Максимальная: \(formatDuration(maxDuration))")
        print()

        // Показываем первые 10 сегментов (или все если меньше)
        let displayCount = min(10, segments.count)
        print("   Первые \(displayCount) сегментов:")
        for (index, segment) in segments.prefix(displayCount).enumerated() {
            let startTime = formatTime(segment.startTime)
            let endTime = formatTime(segment.endTime)
            let duration = formatDuration(segment.duration)
            print("      \(index + 1). [\(startTime) - \(endTime)] (\(duration))")
        }

        if segments.count > displayCount {
            print("      ... и еще \(segments.count - displayCount) сегментов")
        }
        print()
    }

    /// Выводит общую статистику аудио
    static func printAudioStats(_ samples: [Float]) {
        print("📈 Анализ аудио:")

        // RMS (громкость)
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))

        // Пиковая амплитуда
        var maxValue: Float = 0
        vDSP_maxv(samples, 1, &maxValue, vDSP_Length(samples.count))

        var minValue: Float = 0
        vDSP_minv(samples, 1, &minValue, vDSP_Length(samples.count))

        let peakAmplitude = max(abs(maxValue), abs(minValue))

        // Динамический диапазон (dB)
        let dynamicRange = 20 * log10(peakAmplitude / (rms + 0.0001))

        print("   • RMS (средняя громкость): \(String(format: "%.4f", rms))")
        print("   • Пиковая амплитуда: \(String(format: "%.4f", peakAmplitude))")
        print("   • Динамический диапазон: \(String(format: "%.1f", dynamicRange)) dB")

        // Гистограмма RMS по окнам
        print("   • Распределение RMS по времени:")
        analyzeRMSDistribution(samples)
    }

    /// Анализирует распределение RMS по времени
    static func analyzeRMSDistribution(_ samples: [Float]) {
        let windowSize = 16000 // 1 секунда при 16kHz
        var rmsValues: [Float] = []

        var position = 0
        while position + windowSize <= samples.count {
            let window = Array(samples[position..<(position + windowSize)])
            var rms: Float = 0
            vDSP_rmsqv(window, 1, &rms, vDSP_Length(window.count))
            rmsValues.append(rms)
            position += windowSize
        }

        guard !rmsValues.isEmpty else { return }

        // Находим min/max/avg
        let minRMS = rmsValues.min() ?? 0
        let maxRMS = rmsValues.max() ?? 0
        let avgRMS = rmsValues.reduce(0, +) / Float(rmsValues.count)

        print("      Min: \(String(format: "%.4f", minRMS)), " +
              "Avg: \(String(format: "%.4f", avgRMS)), " +
              "Max: \(String(format: "%.4f", maxRMS))")

        // Простая ASCII гистограмма
        let bucketCount = 5
        var buckets = Array(repeating: 0, count: bucketCount)

        for rms in rmsValues {
            let normalized = (rms - minRMS) / (maxRMS - minRMS + 0.0001)
            let bucketIndex = min(Int(normalized * Float(bucketCount)), bucketCount - 1)
            buckets[bucketIndex] += 1
        }

        print("      Гистограмма (от тихого к громкому):")
        for (index, count) in buckets.enumerated() {
            let bar = String(repeating: "█", count: count)
            let label = String(format: "%.4f", minRMS + Float(index) * (maxRMS - minRMS) / Float(bucketCount))
            print("      \(label): \(bar) (\(count))")
        }
    }

    /// Загружает аудио файл и конвертирует в 16kHz mono Float32
    static func loadAudioFile(_ url: URL) async throws -> (samples: [Float], sampleRate: Double, channelCount: Int, duration: TimeInterval) {
        let asset = AVAsset(url: url)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "VADTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Файл не содержит audio track"])
        }

        let reader = try AVAssetReader(asset: asset)

        // Получаем оригинальный sample rate и количество каналов
        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        var originalSampleRate: Double = 16000
        var originalChannelCount: Int = 1

        if let formatDescription = formatDescriptions.first,
           let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
            originalSampleRate = audioStreamBasicDescription.pointee.mSampleRate
            originalChannelCount = Int(audioStreamBasicDescription.pointee.mChannelsPerFrame)
        }

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
            throw NSError(domain: "VADTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не удалось начать чтение файла"])
        }

        var audioSamples: [Float] = []

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

                audioSamples.append(contentsOf: floatArray)
            }
        }

        reader.cancelReading()

        let duration = Double(audioSamples.count) / 16000.0

        return (audioSamples, originalSampleRate, originalChannelCount, duration)
    }

    /// Форматирует длительность в читаемый вид
    static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%dm %ds", minutes, secs)
        }
    }

    /// Форматирует время в формате MM:SS.mmm
    static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, secs, millis)
    }

    /// Тестирует Adaptive VAD с заданными параметрами
    static func testAdaptiveVAD(
        audioSamples: [Float],
        name: String,
        parameters: AdaptiveVAD.Parameters
    ) {
        print("─────────────────────────────────────────────────────────")
        print("📊 \(name)")
        print("   Параметры:")
        print("   • Window Size: \(Int(parameters.windowSize * 1000))ms")
        print("   • Min Speech: \(Int(parameters.minSpeechDuration * 1000))ms")
        print("   • Min Silence: \(Int(parameters.minSilenceDuration * 1000))ms")
        print("   • Threshold Multiplier: \(String(format: "%.2f", parameters.thresholdMultiplier))")
        print("   • ZCR Weight: \(String(format: "%.2f", parameters.zcrWeight))")
        print()

        let vad = AdaptiveVAD(parameters: parameters)
        let segments = vad.detectSpeechSegments(in: audioSamples)

        print("   Результат: \(segments.count) сегментов")

        if segments.isEmpty {
            print("   ⚠️ Сегментов не найдено!")
            print()
            return
        }

        printSegmentStatistics(segments: segments)
    }

    /// Тестирует Spectral VAD с заданными параметрами
    static func testSpectralVAD(
        audioSamples: [Float],
        name: String,
        parameters: SpectralVAD.Parameters
    ) {
        print("─────────────────────────────────────────────────────────")
        print("📊 \(name)")
        print("   Параметры:")
        print("   • FFT Size: \(parameters.fftSize)")
        print("   • Min Speech: \(Int(parameters.minSpeechDuration * 1000))ms")
        print("   • Min Silence: \(Int(parameters.minSilenceDuration * 1000))ms")
        print("   • Speech Freq: \(Int(parameters.speechFreqMin))-\(Int(parameters.speechFreqMax)) Hz")
        print("   • Energy Ratio: \(String(format: "%.2f", parameters.speechEnergyRatio))")
        print()

        let vad = SpectralVAD(parameters: parameters)
        let segments = vad.detectSpeechSegments(in: audioSamples)

        print("   Результат: \(segments.count) сегментов")

        if segments.isEmpty {
            print("   ⚠️ Сегментов не найдено!")
            print()
            return
        }

        printSegmentStatistics(segments: segments)
    }

    /// Выводит статистику по сегментам (общая функция)
    static func printSegmentStatistics(segments: [SpeechSegment]) {
        let totalSpeechDuration = segments.reduce(0.0) { $0 + $1.duration }
        let avgDuration = totalSpeechDuration / Double(segments.count)
        let minDuration = segments.map(\.duration).min() ?? 0
        let maxDuration = segments.map(\.duration).max() ?? 0

        print("   • Общая длительность речи: \(formatDuration(totalSpeechDuration))")
        print("   • Средняя длительность сегмента: \(formatDuration(avgDuration))")
        print("   • Минимальная: \(formatDuration(minDuration))")
        print("   • Максимальная: \(formatDuration(maxDuration))")
        print()

        // Показываем первые 10 сегментов
        let displayCount = min(10, segments.count)
        print("   Первые \(displayCount) сегментов:")
        for (index, segment) in segments.prefix(displayCount).enumerated() {
            let startTime = formatTime(segment.startTime)
            let endTime = formatTime(segment.endTime)
            let duration = formatDuration(segment.duration)
            print("      \(index + 1). [\(startTime) - \(endTime)] (\(duration))")
        }

        if segments.count > displayCount {
            print("      ... и еще \(segments.count - displayCount) сегментов")
        }
        print()
    }

    /// Выводит справку по использованию
    static func printUsage() {
        print("Использование:")
        print("  .build/debug/VADTest <путь_к_аудио_файлу>")
        print()
        print("Пример:")
        print("  .build/debug/VADTest /path/to/audio.wav")
        print()
        print("Инструмент тестирует несколько алгоритмов VAD и выводит статистику:")
        print("  • Количество обнаруженных сегментов речи")
        print("  • Временные метки сегментов")
        print("  • Статистику по длительности")
        print("  • Анализ уровня громкости")
        print()
        print("Алгоритмы:")
        print("  • Standard VAD - энергетический (RMS)")
        print("  • Adaptive VAD - адаптивный порог + ZCR")
        print("  • Spectral VAD - частотный анализ (FFT)")
    }
}
