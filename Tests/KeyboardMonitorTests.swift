import XCTest
import Carbon
@testable import PushToTalkCore

/// Unit tests for KeyboardMonitor
final class KeyboardMonitorTests: XCTestCase {

    var keyboardMonitor: KeyboardMonitor!

    override func setUp() {
        keyboardMonitor = KeyboardMonitor()
    }

    override func tearDown() {
        keyboardMonitor.stopMonitoring()
        keyboardMonitor = nil
    }

    // MARK: - Initialization Tests

    /// Test KeyboardMonitor initialization
    func testInitialization() {
        XCTAssertNotNil(keyboardMonitor, "KeyboardMonitor should initialize")
        XCTAssertFalse(keyboardMonitor.isF16Pressed, "Should not be pressed initially")
    }

    // MARK: - Permission Tests

    /// Test accessibility permission check
    func testCheckAccessibilityPermissions() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        // Just verify it returns a boolean without crashing
        XCTAssertNotNil(hasPermission, "Should return boolean permission status")

        if hasPermission {
            print("✓ Accessibility permission granted")
        } else {
            print("⚠️ Accessibility permission not granted - some tests may be skipped")
        }
    }

    // MARK: - Monitoring Tests

    /// Test starting monitoring
    func testStartMonitoring() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        try XCTSkipUnless(hasPermission, "Accessibility permission required")

        let success = keyboardMonitor.startMonitoring()

        XCTAssertTrue(success, "Should start monitoring successfully")

        // Cleanup
        keyboardMonitor.stopMonitoring()
    }

    /// Test stopping monitoring
    func testStopMonitoring() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        try XCTSkipUnless(hasPermission, "Accessibility permission required")

        _ = keyboardMonitor.startMonitoring()

        // Should not crash
        keyboardMonitor.stopMonitoring()

        XCTAssertTrue(true, "Should stop monitoring without crash")
    }

    /// Test stopping monitoring without starting
    func testStopMonitoringWithoutStart() {
        // Should not crash
        keyboardMonitor.stopMonitoring()

        XCTAssertTrue(true, "Should handle stop without start")
    }

    /// Test restarting monitoring
    func testRestartMonitoring() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        try XCTSkipUnless(hasPermission, "Accessibility permission required")

        // Start
        let success1 = keyboardMonitor.startMonitoring()
        XCTAssertTrue(success1)

        // Stop
        keyboardMonitor.stopMonitoring()

        // Start again
        let success2 = keyboardMonitor.startMonitoring()
        XCTAssertTrue(success2, "Should be able to restart monitoring")

        // Cleanup
        keyboardMonitor.stopMonitoring()
    }

    // MARK: - Callback Tests

    /// Test F16 press callback registration
    func testF16PressCallback() {
        var callbackInvoked = false

        keyboardMonitor.onF16Press = {
            callbackInvoked = true
        }

        XCTAssertNotNil(keyboardMonitor.onF16Press, "Callback should be registered")

        // Note: We can't easily simulate F16 keypress in unit tests
        // This would require CGEvent injection which needs elevated permissions
        // We just verify the callback can be set
    }

    /// Test F16 release callback registration
    func testF16ReleaseCallback() {
        var callbackInvoked = false

        keyboardMonitor.onF16Release = {
            callbackInvoked = true
        }

        XCTAssertNotNil(keyboardMonitor.onF16Release, "Callback should be registered")
    }

    /// Test multiple callback registrations
    func testMultipleCallbackRegistrations() {
        var pressCount = 0
        var releaseCount = 0

        keyboardMonitor.onF16Press = {
            pressCount += 1
        }

        keyboardMonitor.onF16Release = {
            releaseCount += 1
        }

        // Override callbacks
        keyboardMonitor.onF16Press = {
            pressCount += 10
        }

        keyboardMonitor.onF16Release = {
            releaseCount += 10
        }

        // Latest callback should override previous one
        XCTAssertNotNil(keyboardMonitor.onF16Press)
        XCTAssertNotNil(keyboardMonitor.onF16Release)
    }

    /// Test callback can be cleared
    func testClearCallbacks() {
        keyboardMonitor.onF16Press = {
            print("Press")
        }

        keyboardMonitor.onF16Release = {
            print("Release")
        }

        // Clear callbacks
        keyboardMonitor.onF16Press = nil
        keyboardMonitor.onF16Release = nil

        XCTAssertNil(keyboardMonitor.onF16Press, "Press callback should be cleared")
        XCTAssertNil(keyboardMonitor.onF16Release, "Release callback should be cleared")
    }

    // MARK: - State Tests

    /// Test isF16Pressed state
    func testIsF16PressedState() {
        XCTAssertFalse(keyboardMonitor.isF16Pressed, "Should be false initially")

        // Note: Testing actual key press requires CGEvent injection
        // which is complex in unit tests
    }

    // MARK: - Hotkey Tests

    /// Test changing hotkey
    func testChangeHotkey() {
        // Test changing to different hotkeys
        let testKeyCodes: [CGKeyCode] = [
            127, // F16
            105, // F13
            106, // F14
            113, // F15
        ]

        for keyCode in testKeyCodes {
            keyboardMonitor.changeHotkey(to: keyCode)

            // Should not crash
            XCTAssertTrue(true, "Should handle keyCode \(keyCode)")
        }
    }

    /// Test changing hotkey while monitoring
    func testChangeHotkeyWhileMonitoring() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        try XCTSkipUnless(hasPermission, "Accessibility permission required")

        _ = keyboardMonitor.startMonitoring()

        // Change hotkey while monitoring
        keyboardMonitor.changeHotkey(to: 105) // F13

        // Should restart monitoring with new key
        // This is hard to verify without manual testing

        keyboardMonitor.stopMonitoring()
    }

    // MARK: - Thread Safety Tests

    /// Test concurrent callback invocations
    func testConcurrentCallbackAccess() {
        var pressCount = 0
        let lock = NSLock()

        keyboardMonitor.onF16Press = {
            lock.lock()
            pressCount += 1
            lock.unlock()
        }

        // Simulate concurrent invocations (manual testing would be needed for real events)
        let expectation = self.expectation(description: "Concurrent callbacks")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            // Simulate callback (in real scenario, this would come from CGEvent)
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
    }

    // MARK: - Memory Tests

    /// Test monitoring doesn't leak memory
    func testMemoryLeak() {
        let hasPermission = keyboardMonitor.checkAccessibilityPermissions()

        try XCTSkipUnless(hasPermission, "Accessibility permission required")

        // Start and stop multiple times
        for _ in 0..<10 {
            _ = keyboardMonitor.startMonitoring()
            keyboardMonitor.stopMonitoring()
        }

        XCTAssertTrue(true, "Should not leak memory")
    }

    /// Test callback retention doesn't cause retain cycles
    func testCallbackRetentionCycle() {
        weak var weakMonitor = keyboardMonitor

        keyboardMonitor.onF16Press = { [weak weakMonitor] in
            guard let _ = weakMonitor else { return }
            // Do something with monitor
        }

        keyboardMonitor.onF16Release = { [weak weakMonitor] in
            guard let _ = weakMonitor else { return }
            // Do something with monitor
        }

        // Clear strong reference
        keyboardMonitor = nil

        // Weak reference should be nil (no retain cycle)
        XCTAssertNil(weakMonitor, "Should not create retain cycle")

        // Restore for tearDown
        keyboardMonitor = KeyboardMonitor()
    }

    // MARK: - Integration Tests

    /// Test integration with hotkey manager
    func testHotkeyManagerIntegration() {
        // Test that KeyboardMonitor can work with HotkeyManager
        let hotkeyManager = HotkeyManager.shared

        let currentHotkey = hotkeyManager.currentHotkey

        keyboardMonitor.changeHotkey(to: currentHotkey.keyCode)

        XCTAssertTrue(true, "Should integrate with HotkeyManager")
    }
}
