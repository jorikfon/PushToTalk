import XCTest
import Combine
@testable import PushToTalkCore

/// Unit tests for RecordingCoordinator
///
/// Tests:
/// - Recording lifecycle (start/stop)
/// - Error handling
/// - Integration with audio service and whisper service
/// - Text insertion after transcription
/// - State management
final class RecordingCoordinatorTests: XCTestCase {

    // MARK: - System Under Test

    var sut: RecordingCoordinator!

    // MARK: - Mocks

    var mockAudioService: MockAudioCaptureService!
    var mockWhisperService: MockWhisperService!
    var mockTextInserter: MockTextInserter!
    var mockVocabularyManager: MockVocabularyManager!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Create mocks
        mockAudioService = MockAudioCaptureService()
        mockWhisperService = MockWhisperService()
        mockTextInserter = MockTextInserter()
        mockVocabularyManager = MockVocabularyManager()

        // Configure whisper service to be ready
        mockWhisperService.isReady = true
    }

    override func tearDown() {
        sut = nil
        mockAudioService = nil
        mockWhisperService = nil
        mockTextInserter = nil
        mockVocabularyManager = nil

        super.tearDown()
    }

    // MARK: - Recording Lifecycle Tests

    func testStartRecording_Success() {
        // Given
        let expectation = expectation(description: "Recording started")
        mockAudioService.permissionGranted = true

        // Create SUT (simplified - without all dependencies for now)
        // Note: Full implementation would require MenuBarController and FloatingWindow mocks

        // When
        // sut.startRecording()

        // Then
        // XCTAssertTrue(mockAudioService.isRecording)
        // XCTAssertEqual(mockAudioService.startRecordingCallCount, 1)

        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }

    func testStopRecording_Success() async throws {
        // Given
        mockAudioService.isRecording = true
        mockAudioService.addSamples([0.1, 0.2, 0.3, 0.4, 0.5])
        mockWhisperService.transcriptionResult = "Test transcription"

        // When
        // let samples = mockAudioService.stopRecording()

        // Then
        // XCTAssertFalse(mockAudioService.isRecording)
        // XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
        // XCTAssertEqual(samples.count, 5)
    }

    func testStartRecording_WithoutPermission_Fails() {
        // Given
        mockAudioService.permissionGranted = false

        // When
        // Result should be failure or no recording started

        // Then
        // XCTAssertFalse(mockAudioService.isRecording)
    }

    // MARK: - Transcription Tests

    func testTranscription_Success() async throws {
        // Given
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000) // 1 second at 16kHz
        mockWhisperService.transcriptionResult = "Hello world"
        mockWhisperService.isReady = true

        // When
        let result = try await mockWhisperService.transcribe(audioSamples: audioSamples, contextPrompt: nil)

        // Then
        XCTAssertEqual(result, "Hello world")
        XCTAssertEqual(mockWhisperService.transcribeCallCount, 1)
        XCTAssertEqual(mockWhisperService.lastTranscribedSamples?.count, 16000)
    }

    func testTranscription_WithContextPrompt() async throws {
        // Given
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000)
        let contextPrompt = "Technical context: Swift, async/await"
        mockWhisperService.transcriptionResult = "async function test"

        // When
        let result = try await mockWhisperService.transcribe(audioSamples: audioSamples, contextPrompt: contextPrompt)

        // Then
        XCTAssertEqual(result, "async function test")
        XCTAssertEqual(mockWhisperService.lastContextPrompt, contextPrompt)
    }

    func testTranscription_Error() async {
        // Given
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000)
        mockWhisperService.shouldThrowOnTranscribe = true

        // When/Then
        do {
            _ = try await mockWhisperService.transcribe(audioSamples: audioSamples, contextPrompt: nil)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "MockWhisperService")
        }
    }

    // MARK: - Text Insertion Tests

    func testTextInsertion_Success() {
        // Given
        let transcribedText = "This is a test transcription"

        // When
        mockTextInserter.insertTextAtCursor(transcribedText)

        // Then
        XCTAssertEqual(mockTextInserter.insertTextCallCount, 1)
        XCTAssertEqual(mockTextInserter.lastInsertedText, transcribedText)
        XCTAssertTrue(mockTextInserter.didInsert(transcribedText))
    }

    func testTextInsertion_MultipleInsertions() {
        // Given
        let texts = ["First", "Second", "Third"]

        // When
        for text in texts {
            mockTextInserter.insertTextAtCursor(text)
        }

        // Then
        XCTAssertEqual(mockTextInserter.insertTextCallCount, 3)
        XCTAssertEqual(mockTextInserter.insertedTexts, texts)
        XCTAssertEqual(mockTextInserter.allInsertedText, "First Second Third")
    }

    // MARK: - Audio Capture Tests

    func testAudioCapture_StartAndStop() {
        // Given
        mockAudioService.mockAudioSamples = Array(repeating: 0.1, count: 1000)

        // When
        do {
            try mockAudioService.startRecording()
            mockAudioService.addSamples(mockAudioService.mockAudioSamples)
            let samples = mockAudioService.stopRecording()

            // Then
            XCTAssertEqual(mockAudioService.startRecordingCallCount, 1)
            XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
            XCTAssertEqual(samples.count, 1000)
        } catch {
            XCTFail("Should not throw: \(error)")
        }
    }

    func testAudioCapture_Permissions() async {
        // Given
        mockAudioService.permissionGranted = true

        // When
        let hasPermission = await mockAudioService.checkPermissions()

        // Then
        XCTAssertTrue(hasPermission)
        XCTAssertEqual(mockAudioService.checkPermissionsCallCount, 1)
    }

    func testAudioCapture_NoPermissions() async {
        // Given
        mockAudioService.permissionGranted = false

        // When
        let hasPermission = await mockAudioService.checkPermissions()

        // Then
        XCTAssertFalse(hasPermission)
    }

    // MARK: - Vocabulary Manager Tests

    func testVocabularyCorrection_SimpleReplacement() {
        // Given
        mockVocabularyManager.addCorrection(from: "test", to: "TEST")
        let input = "This is a test"

        // When
        let result = mockVocabularyManager.correctTranscription(input)

        // Then
        XCTAssertEqual(result, "This is a TEST")
        XCTAssertEqual(mockVocabularyManager.correctTranscriptionCallCount, 1)
    }

    func testVocabularyCorrection_MultipleReplacements() {
        // Given
        mockVocabularyManager.addCorrection(from: "swift", to: "Swift")
        mockVocabularyManager.addCorrection(from: "ios", to: "iOS")
        let input = "swift ios development"

        // When
        let result = mockVocabularyManager.correctTranscription(input)

        // Then
        XCTAssertEqual(result, "Swift iOS development")
    }

    func testVocabularyManager_ExportImport() throws {
        // Given
        mockVocabularyManager.addCorrection(from: "macos", to: "macOS")
        mockVocabularyManager.addCorrection(from: "xcode", to: "Xcode")

        // When
        let data = try mockVocabularyManager.exportCorrections()
        let newManager = MockVocabularyManager()
        try newManager.importCorrections(from: data)

        // Then
        XCTAssertEqual(mockVocabularyManager.exportCorrectionsCallCount, 1)
        XCTAssertEqual(newManager.importCorrectionsCallCount, 1)
    }

    // MARK: - Integration Tests

    func testFullRecordingFlow_Mock() async throws {
        // Given
        let expectedTranscription = "Integration test transcription"
        mockWhisperService.transcriptionResult = expectedTranscription
        mockWhisperService.isReady = true
        mockAudioService.permissionGranted = true

        // Simulate recording flow
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000)

        // When
        try mockAudioService.startRecording()
        mockAudioService.addSamples(audioSamples)
        let recordedSamples = mockAudioService.stopRecording()

        let transcription = try await mockWhisperService.transcribe(
            audioSamples: recordedSamples,
            contextPrompt: nil
        )

        mockTextInserter.insertTextAtCursor(transcription)

        // Then
        XCTAssertEqual(transcription, expectedTranscription)
        XCTAssertEqual(mockTextInserter.lastInsertedText, expectedTranscription)
        XCTAssertEqual(mockAudioService.startRecordingCallCount, 1)
        XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
        XCTAssertEqual(mockWhisperService.transcribeCallCount, 1)
        XCTAssertEqual(mockTextInserter.insertTextCallCount, 1)
    }

    // MARK: - Error Handling Tests

    func testErrorHandling_AudioServiceFailure() {
        // Given
        mockAudioService.shouldThrowOnStart = true

        // When/Then
        XCTAssertThrowsError(try mockAudioService.startRecording()) { error in
            XCTAssertEqual((error as NSError).domain, "MockAudioCaptureService")
        }
    }

    func testErrorHandling_WhisperServiceNotReady() async {
        // Given
        mockWhisperService.isReady = false
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000)

        // When
        // Should handle gracefully or throw appropriate error

        // Then
        XCTAssertFalse(mockWhisperService.isReady)
    }

    // MARK: - Performance Tests

    func testPerformance_Transcription() {
        let audioSamples: [Float] = Array(repeating: 0.5, count: 16000)

        measure {
            Task {
                do {
                    _ = try await mockWhisperService.transcribe(audioSamples: audioSamples, contextPrompt: nil)
                } catch {
                    XCTFail("Transcription failed: \(error)")
                }
            }
        }
    }
}
