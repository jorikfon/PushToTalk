import Foundation
import PushToTalkCore

/// Benchmark для измерения производительности системы
/// Тестирует:
/// 1. Скорость загрузки модели
/// 2. Время транскрипции для различных длин аудио
/// 3. Real-Time Factor (RTF)
/// 4. Memory usage

class PerformanceBenchmark {
    private let whisperService = WhisperService(modelSize: "tiny")
    private let testDurations: [Double] = [1.0, 3.0, 5.0, 10.0, 15.0, 30.0]  // секунды

    func run() async throws {
        print(String(repeating: "=", count: 70))
        print("⚡ Performance Benchmark - PushToTalk Swift")
        print(String(repeating: "=", count: 70))
        print("")

        // Test 1: Model Loading Time
        try await benchmarkModelLoading()

        // Test 2: Transcription Performance
        try await benchmarkTranscription()

        // Test 3: Overall Statistics
        printOverallStatistics()

        print("")
        print(String(repeating: "=", count: 70))
        print("✅ Benchmark Complete")
        print(String(repeating: "=", count: 70))
    }

    // MARK: - Benchmarks

    /// Тест скорости загрузки модели
    private func benchmarkModelLoading() async throws {
        print("📊 Test 1: Model Loading Performance")
        print(String(repeating: "-", count: 70))

        let startTime = Date()

        try await whisperService.loadModel()

        let loadTime = Date().timeIntervalSince(startTime)

        print("✅ Model loaded in \(String(format: "%.2f", loadTime))s")
        print("")
    }

    /// Тест производительности транскрипции
    private func benchmarkTranscription() async throws {
        print("📊 Test 2: Transcription Performance")
        print(String(repeating: "-", count: 70))
        print("")

        var results: [(duration: Double, time: Double, rtf: Double)] = []

        for duration in testDurations {
            print("🎤 Testing \(String(format: "%.1f", duration))s audio...")

            // Генерируем тестовое аудио (синусоида 440Hz)
            let audioData = generateTestAudio(duration: duration)

            let startTime = Date()

            // Транскрибируем
            _ = try await whisperService.transcribe(audioSamples: audioData)

            let transcriptionTime = Date().timeIntervalSince(startTime)
            let rtf = transcriptionTime / duration

            results.append((duration, transcriptionTime, rtf))

            print("   Duration: \(String(format: "%.1f", duration))s")
            print("   Time: \(String(format: "%.2f", transcriptionTime))s")
            print("   RTF: \(String(format: "%.2f", rtf))x \(rtf < 1.0 ? "✅" : "⚠️")")
            print("   Speed: \(String(format: "%.1f", duration / transcriptionTime))x realtime")
            print("")
        }

        // Анализ результатов
        analyzeResults(results)
    }

    /// Анализ результатов benchmark
    private func analyzeResults(_ results: [(duration: Double, time: Double, rtf: Double)]) {
        print("📈 Analysis:")
        print(String(repeating: "-", count: 70))

        let avgRTF = results.map { $0.rtf }.reduce(0, +) / Double(results.count)
        let minRTF = results.map { $0.rtf }.min() ?? 0
        let maxRTF = results.map { $0.rtf }.max() ?? 0

        print("Average RTF: \(String(format: "%.2f", avgRTF))x")
        print("Min RTF: \(String(format: "%.2f", minRTF))x (best)")
        print("Max RTF: \(String(format: "%.2f", maxRTF))x (worst)")

        // Процент тестов быстрее real-time
        let fasterThanRealtime = results.filter { $0.rtf < 1.0 }.count
        let percentage = Double(fasterThanRealtime) / Double(results.count) * 100

        print("")
        print("Tests faster than realtime: \(fasterThanRealtime)/\(results.count) (\(String(format: "%.0f", percentage))%)")

        if avgRTF < 1.0 {
            print("✅ System can transcribe faster than realtime!")
        } else {
            print("⚠️ System is slower than realtime (avg RTF: \(String(format: "%.2f", avgRTF))x)")
        }

        print("")
    }

    /// Общая статистика
    private func printOverallStatistics() {
        print("📊 Overall Statistics:")
        print(String(repeating: "-", count: 70))

        let stats = whisperService.getPerformanceStats()
        print(stats.description)

        print("")
    }

    // MARK: - Helpers

    /// Генерация тестового аудио (синусоида)
    private func generateTestAudio(duration: Double) -> [Float] {
        let sampleRate: Double = 16000
        let frequency: Double = 440.0  // A4 note
        let sampleCount = Int(duration * sampleRate)

        var samples: [Float] = []
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let sample = Float(sin(2.0 * .pi * frequency * t) * 0.3)  // 30% amplitude
            samples.append(sample)
        }

        return samples
    }
}

// MARK: - Main

print("\n🚀 Starting Performance Benchmark\n")

let benchmark = PerformanceBenchmark()

Task {
    do {
        try await benchmark.run()
        exit(0)
    } catch {
        print("\n❌ Benchmark failed: \(error)")
        exit(1)
    }
}

// Keep running
RunLoop.main.run()
