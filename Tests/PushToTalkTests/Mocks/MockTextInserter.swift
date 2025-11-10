import Foundation
@testable import PushToTalkCore

/// Mock implementation of TextInserterProtocol for testing
public final class MockTextInserter: TextInserterProtocol {

    // MARK: - Call Tracking

    public var insertTextCallCount = 0
    public var insertedTexts: [String] = []
    public var lastInsertedText: String?

    // MARK: - Mock Behavior Configuration

    public var shouldSimulateDelay: Bool = false
    public var insertionDelay: TimeInterval = 0.05

    // MARK: - Initialization

    public init() {}

    // MARK: - TextInserterProtocol

    public func insertTextAtCursor(_ text: String) {
        insertTextCallCount += 1
        insertedTexts.append(text)
        lastInsertedText = text

        // Simulate insertion delay if configured
        if shouldSimulateDelay {
            Thread.sleep(forTimeInterval: insertionDelay)
        }
    }

    // MARK: - Test Helpers

    /// Get all inserted text concatenated
    public var allInsertedText: String {
        return insertedTexts.joined(separator: " ")
    }

    /// Reset all tracking
    public func resetTracking() {
        insertTextCallCount = 0
        insertedTexts = []
        lastInsertedText = nil
    }

    /// Check if specific text was inserted
    public func didInsert(_ text: String) -> Bool {
        return insertedTexts.contains(text)
    }

    /// Check if text containing substring was inserted
    public func didInsertContaining(_ substring: String) -> Bool {
        return insertedTexts.contains { $0.contains(substring) }
    }
}
