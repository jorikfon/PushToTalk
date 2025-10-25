import Foundation
import Cocoa
import PushToTalkCore

/// Тестовая программа для проверки KeyboardMonitor
/// Проверяет:
/// 1. Регистрацию глобальных hotkeys через Carbon API
/// 2. Обнаружение нажатий горячей клавиши (по умолчанию F16)
/// 3. Обработку press/release событий
/// Carbon API НЕ требует Accessibility разрешений для F-клавиш!

class KeyboardMonitorTest {
    private let monitor = KeyboardMonitor()
    private var pressCount = 0
    private var releaseCount = 0
    private let startTime = Date()

    func run() throws {
        print(String(repeating: "=", count: 60))
        print("🎹 Keyboard Monitor Test (Carbon API)")
        print(String(repeating: "=", count: 60))
        print("")

        // Информация о текущей горячей клавише
        let hotkey = HotkeyManager.shared.currentHotkey
        print("ℹ️ Current hotkey: \(hotkey.displayName)")
        print("   Key code: \(hotkey.keyCode)")
        print("   Technology: Carbon Event Manager (RegisterEventHotKey)")
        print("   Permissions: ✅ NO Accessibility permissions required!")
        print("")

        // Настройка обработчиков событий
        monitor.onHotkeyPress = { [weak self] in
            guard let self = self else { return }
            self.pressCount += 1
            let elapsed = Date().timeIntervalSince(self.startTime)
            print("\n🔴 HOTKEY PRESSED (#\(self.pressCount)) at \(String(format: "%.2f", elapsed))s")
        }

        monitor.onHotkeyRelease = { [weak self] in
            guard let self = self else { return }
            self.releaseCount += 1
            let elapsed = Date().timeIntervalSince(self.startTime)
            print("🟢 HOTKEY RELEASED (#\(self.releaseCount)) at \(String(format: "%.2f", elapsed))s")
        }

        // Запуск мониторинга
        print("1️⃣ Starting keyboard monitoring...")
        let started = monitor.startMonitoring()

        if !started {
            print("❌ Failed to start monitoring")
            print("")
            print("This should not happen with Carbon API!")
            print("Check Console logs: log stream --predicate 'subsystem == \"com.pushtotalk.app\" && category == \"keyboard\"'")
            throw TestError.monitoringFailed
        }

        print("✅ Monitoring started successfully")
        print("")

        // Инструкции
        print(String(repeating: "=", count: 60))
        print("📋 Test Instructions:")
        print(String(repeating: "=", count: 60))
        print("")
        print("1. Press and hold \(hotkey.displayName) key")
        print("2. Release \(hotkey.displayName) key")
        print("3. Repeat several times to test press/release detection")
        print("4. Press Ctrl+C to exit")
        print("")
        print("Expected behavior:")
        print("  - Each press should print: 🔴 HOTKEY PRESSED")
        print("  - Each release should print: 🟢 HOTKEY RELEASED")
        print("  - System should NOT perform default action")
        print("")
        print(String(repeating: "=", count: 60))
        print("⏳ Waiting for hotkey events (press Ctrl+C to stop)...")
        print(String(repeating: "=", count: 60))
        print("")

        // Ожидание событий
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
    case monitoringFailed
}

// MARK: - Main

print("\n🚀 Starting Keyboard Monitor Test (Carbon API)\n")

let test = KeyboardMonitorTest()

do {
    try test.run()
} catch {
    print("\n❌ Test failed: \(error)")
    exit(1)
}
