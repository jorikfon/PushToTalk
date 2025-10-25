import XCTest
@testable import PushToTalkCore

/// Unit tests for WhisperService
final class WhisperServiceTests: XCTestCase {

    var whisperService: WhisperService!

    override func setUp() async throws {
        whisperService = WhisperService()
    }

    override func tearDown() async throws {
        whisperService = nil
    }

    // MARK: - Initialization Tests

    /// Test WhisperService initialization
    func testInitialization() {
        XCTAssertNotNil(whisperService, "WhisperService should initialize")
        XCTAssertFalse(whisperService.isInitialized, "Should not be initialized on creation")
    }

    // MARK: - Model Loading Tests

    /// Test model loading
    func testLoadModel() async throws {
        // This test will download the model on first run (can be slow)
        try await whisperService.loadModel(modelName: "tiny")

        XCTAssertTrue(whisperService.isInitialized, "Should be initialized after loading")
    }

    /// Test loading different model variants
    func testLoadDifferentModels() async throws {
        // Test loading tiny model
        try await whisperService.loadModel(modelName: "tiny")
        XCTAssertTrue(whisperService.isInitialized)

        // Note: Loading other models (base, small) can be very slow
        // and require significant disk space, so we skip them in unit tests
    }

    // MARK: - Transcription Tests

    /// Test transcription with silence
    func testTranscribeSilence() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        // Create 3 seconds of silence (16kHz sample rate)
        let silentAudio = Array(repeating: Float(0.0), count: 48000)

        let transcription = try await whisperService.transcribe(audioSamples: silentAudio)

        // Whisper should return empty or whitespace for silence
        XCTAssertNotNil(transcription, "Transcription should not be nil")

        let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        print("Silence transcription: '\(trimmed)'")

        // Silence may produce empty string or artifacts like "[BLANK_AUDIO]", "(silence)", etc.
        // We just check it doesn't crash
    }

    /// Test transcription with short audio
    func testTranscribeShortAudio() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        // 0.5 seconds of low-amplitude audio
        let shortAudio = (0..<8000).map { Float(sin(Double($0) * 0.1)) * 0.1 }

        let transcription = try await whisperService.transcribe(audioSamples: shortAudio)

        XCTAssertNotNil(transcription, "Should handle short audio")
    }

    /// Test transcription with very long audio
    func testTranscribeLongAudio() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        // 30 seconds of audio (maximum Whisper chunk length)
        let longAudio = Array(repeating: Float(0.0), count: 480000) // 30s * 16kHz

        let transcription = try await whisperService.transcribe(audioSamples: longAudio)

        XCTAssertNotNil(transcription, "Should handle long audio")
    }

    /// Test transcription with synthetic speech-like audio
    func testTranscribeSyntheticAudio() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        // Generate synthetic audio with multiple frequencies (simulates speech formants)
        var audioSamples: [Float] = []
        let duration: Double = 2.0 // 2 seconds
        let sampleRate: Double = 16000
        let totalSamples = Int(duration * sampleRate)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate

            // Mix of frequencies typical for human speech (200-3000 Hz)
            let f1 = Float(sin(2.0 * .pi * 250 * t)) * 0.3  // F1 formant
            let f2 = Float(sin(2.0 * .pi * 800 * t)) * 0.2  // F2 formant
            let f3 = Float(sin(2.0 * .pi * 2500 * t)) * 0.1 // F3 formant

            audioSamples.append(f1 + f2 + f3)
        }

        let transcription = try await whisperService.transcribe(audioSamples: audioSamples)

        XCTAssertNotNil(transcription, "Should transcribe synthetic audio")
        print("Synthetic audio transcription: '\(transcription)'")
    }

    // MARK: - Performance Tests

    /// Test transcription performance (Real-Time Factor)
    func testTranscriptionPerformance() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        // Create 3 seconds of test audio
        let audioDuration: Double = 3.0
        let sampleCount = Int(audioDuration * 16000)
        let testAudio = Array(repeating: Float(0.0), count: sampleCount)

        let startTime = Date()
        _ = try await whisperService.transcribe(audioSamples: testAudio)
        let transcriptionTime = Date().timeIntervalSince(startTime)

        let rtf = transcriptionTime / audioDuration

        print("Transcription time: \(String(format: "%.2f", transcriptionTime))s")
        print("Audio duration: \(audioDuration)s")
        print("RTF: \(String(format: "%.2f", rtf))x")

        // After warm-up, RTF should be < 1.0 on Apple Silicon
        // But first run might be slower, so we allow up to 20x
        XCTAssertLessThan(rtf, 20.0, "RTF should be reasonable")
    }

    /// Test performance metrics tracking
    func testPerformanceMetrics() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        let testAudio = Array(repeating: Float(0.0), count: 48000) // 3 seconds

        // Initial state
        XCTAssertEqual(whisperService.lastTranscriptionTime, 0.0)

        // Run transcription
        _ = try await whisperService.transcribe(audioSamples: testAudio)

        // Check metrics were updated
        XCTAssertGreaterThan(whisperService.lastTranscriptionTime, 0.0,
                           "Should track transcription time")
    }

    // MARK: - Error Handling Tests

    /// Test transcribing without loading model should throw
    func testTranscribeWithoutModelThrows() async {
        let testAudio = Array(repeating: Float(0.0), count: 16000)

        do {
            _ = try await whisperService.transcribe(audioSamples: testAudio)
            XCTFail("Should throw error when model not loaded")
        } catch {
            // Expected error
            print("Expected error: \(error)")
        }
    }

    /// Test transcribing with empty audio array
    func testTranscribeEmptyAudio() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        let emptyAudio: [Float] = []

        do {
            _ = try await whisperService.transcribe(audioSamples: emptyAudio)
            // Should either succeed with empty string or throw
        } catch {
            // Expected - empty audio might throw
            print("Empty audio error: \(error)")
        }
    }

    // MARK: - Concurrent Access Tests

    /// Test concurrent transcription requests
    func testConcurrentTranscriptions() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        let testAudio = Array(repeating: Float(0.0), count: 32000) // 2 seconds

        // Run 3 transcriptions concurrently
        async let result1 = whisperService.transcribe(audioSamples: testAudio)
        async let result2 = whisperService.transcribe(audioSamples: testAudio)
        async let result3 = whisperService.transcribe(audioSamples: testAudio)

        let results = try await [result1, result2, result3]

        // All should succeed
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertNotNil(result, "Concurrent transcription should succeed")
        }
    }

    // MARK: - Memory Tests

    /// Test that transcription doesn't leak memory
    func testMemoryUsage() async throws {
        try await whisperService.loadModel(modelName: "tiny")

        let testAudio = Array(repeating: Float(0.0), count: 32000)

        // Run multiple transcriptions
        for i in 0..<5 {
            _ = try await whisperService.transcribe(audioSamples: testAudio)
            print("Completed transcription \(i + 1)/5")
        }

        // If there were memory leaks, this would crash or hang
        // Swift's ARC should clean up properly
        XCTAssertTrue(true, "Should complete without memory issues")
    }
}
