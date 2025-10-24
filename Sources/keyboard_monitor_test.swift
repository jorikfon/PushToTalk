import Foundation
import Cocoa
import PushToTalkCore

/// Тестовая программа для проверки KeyboardMonitor
/// Проверяет:
/// 1. Accessibility разрешения
/// 2. Обнаружение нажатий F16
/// 3. Обработку press/release событий

class KeyboardMonitorTest {
    private let monitor = KeyboardMonitor()
    private var pressCount = 0
    private var releaseCount = 0
    private let startTime = Date()

    func run() throws {
        print(String(repeating: "=", count: 60))
        print("🎹 Keyboard Monitor Test")
        print(String(repeating: "=", count: 60))
        print("")

        // Шаг 1: Проверка Accessibility разрешений
        print("1️⃣ Checking Accessibility Permissions...")
        let hasPermissions = monitor.checkAccessibilityPermissions()

        if !hasPermissions {
            print("")
            print("❌ Accessibility permissions NOT granted")
            print("")
            print("⚠️ To grant permissions:")
            print("   1. Open System Settings > Privacy & Security > Accessibility")
            print("   2. Enable access for Terminal or your IDE")
            print("   3. Re-run this test")
            print("")
            throw TestError.accessibilityDenied
        }

        print("✅ Accessibility permissions granted")
        print("")

        // Шаг 2: Настройка обработчиков событий
        monitor.onF16Press = { [weak self] in
            guard let self = self else { return }
            self.pressCount += 1
            let elapsed = Date().timeIntervalSince(self.startTime)
            print("\n🔴 F16 PRESSED (#\(self.pressCount)) at \(String(format: "%.2f", elapsed))s")
        }

        monitor.onF16Release = { [weak self] in
            guard let self = self else { return }
            self.releaseCount += 1
            let elapsed = Date().timeIntervalSince(self.startTime)
            print("🟢 F16 RELEASED (#\(self.releaseCount)) at \(String(format: "%.2f", elapsed))s")
        }

        // Шаг 3: Запуск мониторинга
        print("2️⃣ Starting keyboard monitoring...")
        let started = monitor.startMonitoring()

        if !started {
            print("❌ Failed to start monitoring")
            throw TestError.monitoringFailed
        }

        print("✅ Monitoring started successfully")
        print("")

        // Инструкции
        print(String(repeating: "=", count: 60))
        print("📋 Test Instructions:")
        print(String(repeating: "=", count: 60))
        print("")
        print("1. Press and hold F16 key (top-right on Mac keyboards)")
        print("2. Release F16 key")
        print("3. Repeat several times to test press/release detection")
        print("4. Press Ctrl+C to exit")
        print("")
        print("Expected behavior:")
        print("  - Each F16 press should print: 🔴 F16 PRESSED")
        print("  - Each F16 release should print: 🟢 F16 RELEASED")
        print("  - System should NOT perform default F16 action")
        print("")
        print(String(repeating: "=", count: 60))
        print("⏳ Waiting for F16 events (press Ctrl+C to stop)...")
        print(String(repeating: "=", count: 60))
        print("")

        // Шаг 4: Ожидание событий
        // Запускаем RunLoop для обработки событий
        let runLoop = RunLoop.main

        // Устанавливаем обработчик Ctrl+C
        signal(SIGINT) { _ in
            print("\n\n📊 Test Summary:")
            print(String(repeating: "=", count: 60))
            exit(0)
        }

        // Периодически выводим статистику
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.printStatistics()
        }

        // Запускаем RunLoop бесконечно
        while true {
            _ = runLoop.run(mode: .default, before: .distantFuture)
        }
    }

    private func printStatistics() {
        let elapsed = Date().timeIntervalSince(startTime)
        print("\n📊 Statistics (after \(Int(elapsed))s):")
        print("   - Press events:   \(pressCount)")
        print("   - Release events: \(releaseCount)")
        print("   - Press/Release ratio: \(pressCount > 0 ? String(format: "%.1f", Double(releaseCount) / Double(pressCount)) : "N/A")")
        if pressCount == releaseCount {
            print("   ✅ Press/Release count is balanced")
        } else {
            print("   ⚠️ Press/Release count mismatch")
        }
        print("")
    }
}

enum TestError: Error {
    case accessibilityDenied
    case monitoringFailed
}

// MARK: - Main

print("\n🚀 Starting Keyboard Monitor Test\n")

let test = KeyboardMonitorTest()

do {
    try test.run()
} catch {
    print("\n❌ Test failed: \(error)")
    exit(1)
}
