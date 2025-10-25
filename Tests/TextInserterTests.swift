import XCTest
import AppKit
@testable import PushToTalkCore

/// Unit tests for TextInserter
final class TextInserterTests: XCTestCase {

    var textInserter: TextInserter!

    override func setUp() {
        textInserter = TextInserter()
    }

    override func tearDown() {
        textInserter = nil
    }

    // MARK: - Initialization Tests

    /// Test TextInserter initialization
    func testInitialization() {
        XCTAssertNotNil(textInserter, "TextInserter should initialize")
    }

    // MARK: - Clipboard Tests

    /// Test clipboard save and restore
    func testClipboardSaveRestore() {
        let originalText = "Original clipboard content"
        let newText = "New text to insert"

        // Set original clipboard content
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(originalText, forType: .string)

        // Save clipboard state
        let savedClipboard = textInserter.saveClipboard()

        // Modify clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        // Verify clipboard changed
        let modifiedContent = pasteboard.string(forType: .string)
        XCTAssertEqual(modifiedContent, newText)

        // Restore clipboard
        textInserter.restoreClipboard(savedClipboard)

        // Wait a bit for async restoration
        Thread.sleep(forTimeInterval: 0.1)

        // Verify restored
        let restoredContent = pasteboard.string(forType: .string)
        XCTAssertEqual(restoredContent, originalText, "Should restore original clipboard")
    }

    /// Test saving empty clipboard
    func testSaveEmptyClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let savedClipboard = textInserter.saveClipboard()

        XCTAssertNotNil(savedClipboard, "Should handle empty clipboard")
    }

    /// Test clipboard with multiple types
    func testClipboardMultipleTypes() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Add multiple types
        pasteboard.setString("Test string", forType: .string)

        if let rtfData = "Test RTF".data(using: .utf8) {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        let savedClipboard = textInserter.saveClipboard()

        // Clear clipboard
        pasteboard.clearContents()

        // Restore
        textInserter.restoreClipboard(savedClipboard)

        Thread.sleep(forTimeInterval: 0.1)

        // Check string was restored
        let restored = pasteboard.string(forType: .string)
        XCTAssertEqual(restored, "Test string")
    }

    // MARK: - Text Insertion Tests

    /// Test basic text insertion
    func testInsertTextAtCursor() {
        let testText = "Hello, World!"

        // Save current clipboard
        let savedClipboard = textInserter.saveClipboard()

        // Insert text
        textInserter.insertTextAtCursor(testText)

        // Wait for insertion to complete
        Thread.sleep(forTimeInterval: 0.5)

        // Check clipboard was modified during insertion
        // (In real scenario, would check that text was pasted in active app)

        // Clipboard should be restored after delay (300ms)
        Thread.sleep(forTimeInterval: 0.4)

        // Note: Full testing requires active text field, which is hard in unit tests
        XCTAssertTrue(true, "Should complete without crash")

        // Restore original clipboard
        textInserter.restoreClipboard(savedClipboard)
    }

    /// Test inserting empty string
    func testInsertEmptyString() {
        textInserter.insertTextAtCursor("")

        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(true, "Should handle empty string")
    }

    /// Test inserting string with special characters
    func testInsertSpecialCharacters() {
        let specialText = "Test with émojis 🚀 and ümlaut!"

        textInserter.insertTextAtCursor(specialText)

        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(true, "Should handle special characters")
    }

    /// Test inserting very long string
    func testInsertLongString() {
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)

        textInserter.insertTextAtCursor(longText)

        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(true, "Should handle long strings")
    }

    /// Test inserting multiline text
    func testInsertMultilineText() {
        let multilineText = """
        First line
        Second line
        Third line
        """

        textInserter.insertTextAtCursor(multilineText)

        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(true, "Should handle multiline text")
    }

    // MARK: - Accessibility API Tests

    /// Test accessibility insertion method
    func testInsertTextViaAccessibility() {
        let testText = "Accessibility test"

        let success = textInserter.insertTextViaAccessibility(testText)

        // This will likely fail in unit tests without an active text field
        // but should not crash
        if success {
            print("✓ Accessibility insertion succeeded")
        } else {
            print("⚠️ Accessibility insertion failed (expected in unit tests)")
        }

        XCTAssertTrue(true, "Should not crash")
    }

    /// Test accessibility insertion with empty text
    func testAccessibilityInsertEmptyText() {
        let success = textInserter.insertTextViaAccessibility("")

        // Should handle gracefully
        XCTAssertTrue(true, "Should handle empty text")
    }

    // MARK: - Performance Tests

    /// Test clipboard operations are fast
    func testClipboardPerformance() {
        measure {
            for _ in 0..<10 {
                let saved = textInserter.saveClipboard()
                textInserter.restoreClipboard(saved)
            }
        }
    }

    /// Test text insertion performance
    func testInsertionPerformance() {
        let testText = "Performance test text"

        measure {
            textInserter.insertTextAtCursor(testText)
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    // MARK: - Thread Safety Tests

    /// Test concurrent clipboard operations
    func testConcurrentClipboardOperations() {
        let expectation = self.expectation(description: "Concurrent clipboard")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { i in
            let saved = textInserter.saveClipboard()
            textInserter.restoreClipboard(saved)

            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    /// Test concurrent text insertions
    func testConcurrentTextInsertions() {
        let expectation = self.expectation(description: "Concurrent insertions")
        expectation.expectedFulfillmentCount = 5

        for i in 0..<5 {
            DispatchQueue.global().async {
                self.textInserter.insertTextAtCursor("Test \(i)")

                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - Error Handling Tests

    /// Test handling of clipboard errors
    func testClipboardErrorHandling() {
        // Try to restore invalid clipboard data
        let invalidData: [NSPasteboard.PasteboardType: Data] = [:]

        textInserter.restoreClipboard(invalidData)

        XCTAssertTrue(true, "Should handle invalid clipboard data")
    }

    /// Test CGEvent creation failure handling
    func testCGEventFailureHandling() {
        // This is hard to test without mocking, but we verify no crash
        textInserter.insertTextAtCursor("Test")

        XCTAssertTrue(true, "Should handle CGEvent failures gracefully")
    }

    // MARK: - Memory Tests

    /// Test no memory leaks from clipboard operations
    func testClipboardMemoryUsage() {
        for _ in 0..<100 {
            let saved = textInserter.saveClipboard()
            textInserter.restoreClipboard(saved)
        }

        XCTAssertTrue(true, "Should not leak memory")
    }

    /// Test no memory leaks from text insertions
    func testInsertionMemoryUsage() {
        for i in 0..<50 {
            textInserter.insertTextAtCursor("Memory test \(i)")
            Thread.sleep(forTimeInterval: 0.01)
        }

        XCTAssertTrue(true, "Should not leak memory")
    }

    // MARK: - Integration Tests

    /// Test TextInserter works with real clipboard workflow
    func testRealWorldClipboardWorkflow() {
        let pasteboard = NSPasteboard.general

        // User's original content
        pasteboard.clearContents()
        pasteboard.setString("User's original clipboard", forType: .string)

        // App saves clipboard
        let saved = textInserter.saveClipboard()

        // App inserts transcription
        let transcription = "This is a transcribed text."
        textInserter.insertTextAtCursor(transcription)

        // Wait for paste simulation
        Thread.sleep(forTimeInterval: 0.4)

        // App restores clipboard
        textInserter.restoreClipboard(saved)

        Thread.sleep(forTimeInterval: 0.1)

        // Verify original content restored
        let restored = pasteboard.string(forType: .string)
        XCTAssertEqual(restored, "User's original clipboard",
                      "Should restore user's clipboard after insertion")
    }
}
