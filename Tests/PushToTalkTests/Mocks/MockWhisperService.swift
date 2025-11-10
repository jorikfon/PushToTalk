import Foundation
import Combine
@testable import PushToTalkCore

/// Mock implementation of WhisperServiceProtocol for testing
public final class MockWhisperService: WhisperServiceProtocol {

    // MARK: - Properties

    public var isReady: Bool = false
    public var currentModelSize: String = "base"
    public var promptText: String? = nil
    public var enableNormalization: Bool = false
    public var lastTranscriptionTime: TimeInterval = 0.0
    public var averageRTF: Double = 0.0

    // MARK: - Mock Behavior Configuration

    public var shouldThrowOnLoadModel: Bool = false
    public var shouldThrowOnReload: Bool = false
    public var shouldThrowOnTranscribe: Bool = false
    public var transcriptionResult: String = "Mock transcription"
    public var transcriptionDelay: TimeInterval = 0.0
    public var mockPerformanceStats: PerformanceStats = PerformanceStats(
        lastTranscriptionTime: 0.0,
        averageRTF: 0.0,
        transcriptionCount: 0,
        modelSize: "base"
    )

    // MARK: - Call Tracking

    public var loadModelCallCount = 0
    public var reloadModelCallCount = 0
    public var transcribeCallCount = 0
    public var transcribeChunkCallCount = 0
    public var getPerformanceStatsCallCount = 0
    public var resetPerformanceStatsCallCount = 0

    public var lastReloadedModelSize: String?
    public var lastTranscribedSamples: [Float]?
    public var lastContextPrompt: String?

    // MARK: - Convenience Computed Properties

    public var reloadModelCalled: Bool {
        return reloadModelCallCount > 0
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - WhisperServiceProtocol

    public func loadModel() async throws {
        loadModelCallCount += 1

        if shouldThrowOnLoadModel {
            throw NSError(domain: "MockWhisperService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Mock load model error"
            ])
        }

        if transcriptionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcriptionDelay * 1_000_000_000))
        }

        isReady = true
    }

    public func reloadModel(newModelSize: String) async throws {
        reloadModelCallCount += 1
        lastReloadedModelSize = newModelSize

        if shouldThrowOnReload {
            throw NSError(domain: "MockWhisperService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Mock reload model error"
            ])
        }

        if transcriptionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcriptionDelay * 1_000_000_000))
        }

        currentModelSize = newModelSize
        isReady = true
    }

    public func transcribe(audioSamples: [Float], contextPrompt: String?) async throws -> String {
        transcribeCallCount += 1
        lastTranscribedSamples = audioSamples
        lastContextPrompt = contextPrompt

        if shouldThrowOnTranscribe {
            throw NSError(domain: "MockWhisperService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Mock transcription error"
            ])
        }

        if transcriptionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcriptionDelay * 1_000_000_000))
        }

        lastTranscriptionTime = transcriptionDelay
        return transcriptionResult
    }

    public func transcribeChunk(audioSamples: [Float]) async throws -> String {
        transcribeChunkCallCount += 1
        lastTranscribedSamples = audioSamples

        if shouldThrowOnTranscribe {
            throw NSError(domain: "MockWhisperService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Mock chunk transcription error"
            ])
        }

        if transcriptionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcriptionDelay * 1_000_000_000))
        }

        return transcriptionResult
    }

    public func getPerformanceStats() -> PerformanceStats {
        getPerformanceStatsCallCount += 1
        return mockPerformanceStats
    }

    public func resetPerformanceStats() {
        resetPerformanceStatsCallCount += 1
        lastTranscriptionTime = 0.0
        averageRTF = 0.0
        mockPerformanceStats = PerformanceStats(
            lastTranscriptionTime: 0.0,
            averageRTF: 0.0,
            transcriptionCount: 0,
            modelSize: currentModelSize
        )
    }
}
