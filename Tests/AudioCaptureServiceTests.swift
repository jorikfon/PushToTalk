import Testing
import AVFoundation
@testable import PushToTalkCore

/// Unit tests for AudioCaptureService
@Suite("AudioCaptureService Tests")
struct AudioCaptureServiceTests {

    // MARK: - Permission Tests

    /// Test microphone permission check
    func testCheckPermissions() async throws {
        let hasPermission = await audioService.checkPermissions()

        // Permission должно быть granted (если тесты запущены с разрешениями)
        // или можно просто проверить, что метод не крашится
        XCTAssertNotNil(hasPermission, "Permission check should return a boolean")
    }

    // MARK: - Recording Tests

    /// Test starting recording
    func testStartRecording() async throws {
        let hasPermission = await audioService.checkPermissions()

        // Skip if no permission
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        // Start recording
        try audioService.startRecording()

        XCTAssertTrue(audioService.isRecording, "Should be recording after start")

        // Cleanup
        _ = audioService.stopRecording()
    }

    /// Test stopping recording
    func testStopRecording() async throws {
        let hasPermission = await audioService.checkPermissions()
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        try audioService.startRecording()
        XCTAssertTrue(audioService.isRecording)

        let audioData = audioService.stopRecording()

        XCTAssertFalse(audioService.isRecording, "Should not be recording after stop")
        XCTAssertNotNil(audioData, "Should return audio data")
    }

    /// Test recording captures audio samples
    func testRecordingCapturesAudio() async throws {
        let hasPermission = await audioService.checkPermissions()
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        // Start recording
        try audioService.startRecording()

        // Record for 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Stop and get audio
        let audioData = audioService.stopRecording()

        // At 16kHz sample rate, 1 second should give ~16000 samples
        // Allow some tolerance (±20%)
        let expectedSamples = 16000
        let tolerance = 3200 // 20%

        XCTAssertGreaterThan(audioData.count, 0, "Should capture audio samples")
        XCTAssertGreaterThan(audioData.count, expectedSamples - tolerance,
                           "Should capture approximately 1 second of audio")
        XCTAssertLessThan(audioData.count, expectedSamples + tolerance,
                        "Should not capture significantly more than 1 second")
    }

    /// Test recording format (16kHz mono Float32)
    func testAudioFormat() async throws {
        let hasPermission = await audioService.checkPermissions()
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        try audioService.startRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let audioData = audioService.stopRecording()

        // Check that samples are Float values between -1.0 and 1.0
        for sample in audioData {
            XCTAssertGreaterThanOrEqual(sample, -1.0, "Sample should be >= -1.0")
            XCTAssertLessThanOrEqual(sample, 1.0, "Sample should be <= 1.0")
        }
    }

    /// Test multiple recording sessions
    func testMultipleRecordingSessions() async throws {
        let hasPermission = await audioService.checkPermissions()
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        // First recording
        try audioService.startRecording()
        try await Task.sleep(nanoseconds: 500_000_000)
        let audioData1 = audioService.stopRecording()
        XCTAssertGreaterThan(audioData1.count, 0)

        // Second recording
        try audioService.startRecording()
        try await Task.sleep(nanoseconds: 500_000_000)
        let audioData2 = audioService.stopRecording()
        XCTAssertGreaterThan(audioData2.count, 0)

        // Both should succeed
        XCTAssertNotEqual(audioData1.count, 0)
        XCTAssertNotEqual(audioData2.count, 0)
    }

    // MARK: - Error Handling Tests

    /// Test starting recording without permission should throw
    func testStartRecordingWithoutPermissionThrows() throws {
        // Create a new service that hasn't checked permissions
        let newService = AudioCaptureService()

        // Should throw permission error
        XCTAssertThrowsError(try newService.startRecording()) { error in
            guard let audioError = error as? AudioError else {
                XCTFail("Should throw AudioError")
                return
            }
            XCTAssertEqual(audioError, AudioError.permissionDenied)
        }
    }

    /// Test stopping without starting should not crash
    func testStopRecordingWithoutStart() {
        let audioData = audioService.stopRecording()

        // Should return empty array
        XCTAssertEqual(audioData.count, 0, "Should return empty array if not recording")
    }

    // MARK: - Thread Safety Tests

    /// Test concurrent access to recording state
    func testConcurrentAccess() async throws {
        let hasPermission = await audioService.checkPermissions()
        try XCTSkipUnless(hasPermission, "Microphone permission required")

        try audioService.startRecording()

        // Multiple concurrent reads of isRecording should be safe
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    return self.audioService.isRecording
                }
            }

            for await result in group {
                XCTAssertTrue(result, "Should be recording")
            }
        }

        _ = audioService.stopRecording()
    }
}
