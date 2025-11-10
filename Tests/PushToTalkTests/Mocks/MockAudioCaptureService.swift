import Foundation
import Combine
@testable import PushToTalkCore

/// Mock implementation of AudioCaptureServiceProtocol for testing
public final class MockAudioCaptureService: AudioCaptureServiceProtocol, ObservableObject {

    // MARK: - Properties

    @Published public var isRecording: Bool = false
    @Published public var permissionGranted: Bool = true

    public var onAudioChunkReady: (([Float]) -> Void)?

    // AsyncStream support
    private var chunkContinuation: AsyncStream<[Float]>.Continuation?
    public private(set) lazy var audioChunks: AsyncStream<[Float]> = {
        AsyncStream { continuation in
            self.chunkContinuation = continuation
        }
    }()

    // MARK: - Mock Behavior Configuration

    public var shouldThrowOnStart: Bool = false
    public var mockAudioSamples: [Float] = []
    public var shouldSimulateChunks: Bool = false
    public var chunkSimulationDelay: TimeInterval = 0.1

    // MARK: - Call Tracking

    public var checkPermissionsCallCount = 0
    public var startRecordingCallCount = 0
    public var stopRecordingCallCount = 0
    public var clearBufferCallCount = 0

    public var recordedSamples: [Float] = []

    // MARK: - Initialization

    public init() {}

    // MARK: - AudioCaptureServiceProtocol

    public func checkPermissions() async -> Bool {
        checkPermissionsCallCount += 1
        return permissionGranted
    }

    public func startRecording() throws {
        startRecordingCallCount += 1

        if shouldThrowOnStart {
            throw NSError(domain: "MockAudioCaptureService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Mock start recording error"
            ])
        }

        isRecording = true
        recordedSamples = []

        // Simulate audio chunk generation if configured
        if shouldSimulateChunks {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(chunkSimulationDelay * 1_000_000_000))
                if isRecording {
                    simulateAudioChunk()
                }
            }
        }
    }

    public func stopRecording() -> [Float] {
        stopRecordingCallCount += 1
        isRecording = false

        let samples = recordedSamples
        recordedSamples = []
        return samples
    }

    public func clearBuffer() {
        clearBufferCallCount += 1
        recordedSamples = []
    }

    // MARK: - Test Helpers

    /// Simulate receiving an audio chunk
    public func simulateAudioChunk(_ samples: [Float]? = nil) {
        let chunk = samples ?? mockAudioSamples
        recordedSamples.append(contentsOf: chunk)

        // Call callback if set
        onAudioChunkReady?(chunk)

        // Send to AsyncStream
        chunkContinuation?.yield(chunk)
    }

    /// Add samples to the buffer (simulating recording)
    public func addSamples(_ samples: [Float]) {
        recordedSamples.append(contentsOf: samples)
    }

    /// Reset all tracking counters
    public func resetTracking() {
        checkPermissionsCallCount = 0
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        clearBufferCallCount = 0
        recordedSamples = []
    }
}
