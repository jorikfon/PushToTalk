import Foundation
@testable import PushToTalkCore

/// Mock implementation of VocabularyManagerProtocol for testing
public final class MockVocabularyManager: VocabularyManagerProtocol {

    // MARK: - Mock Data

    private var corrections: [String: String] = [:]
    private var regexCorrections: [(pattern: String, replacement: String)] = []

    // MARK: - Call Tracking

    public var addCorrectionCallCount = 0
    public var addRegexCorrectionCallCount = 0
    public var removeCorrectionCallCount = 0
    public var clearCorrectionsCallCount = 0
    public var resetToDefaultsCallCount = 0
    public var correctTranscriptionCallCount = 0
    public var getAllCorrectionsCallCount = 0
    public var exportCorrectionsCallCount = 0
    public var importCorrectionsCallCount = 0

    public var lastCorrectionAdded: (from: String, to: String)?
    public var lastRegexAdded: (pattern: String, replacement: String)?
    public var lastCorrectedText: String?

    // MARK: - Mock Behavior Configuration

    public var shouldThrowOnExport: Bool = false
    public var shouldThrowOnImport: Bool = false
    public var customCorrectionResult: String?

    // MARK: - Initialization

    public init() {}

    // MARK: - VocabularyManagerProtocol

    public func addCorrection(from: String, to: String) {
        addCorrectionCallCount += 1
        lastCorrectionAdded = (from, to)
        corrections[from] = to
    }

    public func addRegexCorrection(pattern: String, replacement: String) throws {
        addRegexCorrectionCallCount += 1
        lastRegexAdded = (pattern, replacement)
        regexCorrections.append((pattern, replacement))
    }

    public func removeCorrection(for incorrect: String) {
        removeCorrectionCallCount += 1
        corrections.removeValue(forKey: incorrect)
    }

    public func clearCorrections() {
        clearCorrectionsCallCount += 1
        corrections.removeAll()
        regexCorrections.removeAll()
    }

    public func resetToDefaults() {
        resetToDefaultsCallCount += 1
        corrections = [
            "test": "TEST",
            "mock": "MOCK"
        ]
        regexCorrections = []
    }

    public func correctTranscription(_ text: String) -> String {
        correctTranscriptionCallCount += 1
        lastCorrectedText = text

        // Return custom result if configured
        if let custom = customCorrectionResult {
            return custom
        }

        // Apply simple corrections
        var result = text
        for (from, to) in corrections {
            result = result.replacingOccurrences(of: from, with: to)
        }

        // Apply regex corrections (simplified for mock)
        for (pattern, replacement) in regexCorrections {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: replacement
                )
            }
        }

        return result
    }

    public func getAllCorrections() -> [String: String] {
        getAllCorrectionsCallCount += 1
        return corrections
    }

    public func exportCorrections() throws -> Data {
        exportCorrectionsCallCount += 1

        if shouldThrowOnExport {
            throw NSError(domain: "MockVocabularyManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Mock export error"
            ])
        }

        let dict = ["corrections": corrections, "regexCorrections": regexCorrections.map { ["pattern": $0.pattern, "replacement": $0.replacement] }] as [String: Any]
        return try JSONSerialization.data(withJSONObject: dict)
    }

    public func importCorrections(from data: Data) throws {
        importCorrectionsCallCount += 1

        if shouldThrowOnImport {
            throw NSError(domain: "MockVocabularyManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Mock import error"
            ])
        }

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let importedCorrections = dict["corrections"] as? [String: String] else {
            throw NSError(domain: "MockVocabularyManager", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Invalid data format"
            ])
        }

        corrections = importedCorrections
    }

    // MARK: - Test Helpers

    public func resetTracking() {
        addCorrectionCallCount = 0
        addRegexCorrectionCallCount = 0
        removeCorrectionCallCount = 0
        clearCorrectionsCallCount = 0
        resetToDefaultsCallCount = 0
        correctTranscriptionCallCount = 0
        getAllCorrectionsCallCount = 0
        exportCorrectionsCallCount = 0
        importCorrectionsCallCount = 0

        lastCorrectionAdded = nil
        lastRegexAdded = nil
        lastCorrectedText = nil
    }
}
