import Foundation
import AVFoundation
import ApplicationServices

/// Менеджер разрешений для всех необходимых системных доступов
public class PermissionManager {
    public static let shared = PermissionManager()

    private init() {
        print("PermissionManager: Инициализация")
    }

    // MARK: - Microphone Permissions

    /// Проверка разрешения на микрофон
    public func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("PermissionManager: ✓ Микрофон - разрешено")
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            print("PermissionManager: Микрофон - запрошено разрешение: \(granted ? "✓" : "✗")")
            return granted
        case .denied, .restricted:
            print("PermissionManager: ✗ Микрофон - отказано")
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Accessibility Permissions

    /// Проверка Accessibility разрешений (для мониторинга клавиатуры)
    public func checkAccessibilityPermission(prompt: Bool = true) -> Bool {
        let options: CFDictionary? = prompt ? [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary : nil

        let trusted = options != nil ? AXIsProcessTrustedWithOptions(options) : AXIsProcessTrusted()

        if trusted {
            print("PermissionManager: ✓ Accessibility - разрешено")
        } else {
            print("PermissionManager: ✗ Accessibility - отказано")
        }

        return trusted
    }

    // MARK: - Check All Permissions

    /// Проверка всех необходимых разрешений
    public func checkAllPermissions() async -> PermissionStatus {
        let micPermission = await checkMicrophonePermission()
        let accessibilityPermission = checkAccessibilityPermission(prompt: true)

        return PermissionStatus(
            microphone: micPermission,
            accessibility: accessibilityPermission
        )
    }

    // MARK: - Permission Guidance

    /// Показать инструкции по предоставлению разрешений
    public func showPermissionInstructions(for permission: PermissionType) -> String {
        switch permission {
        case .microphone:
            return """
            Для работы PushToTalk требуется доступ к микрофону.

            Как предоставить доступ:
            1. Откройте System Settings
            2. Перейдите в Privacy & Security
            3. Выберите Microphone
            4. Включите PushToTalk в списке
            """

        case .accessibility:
            return """
            Для отслеживания клавиши F16 требуется Accessibility доступ.

            Как предоставить доступ:
            1. Откройте System Settings
            2. Перейдите в Privacy & Security
            3. Выберите Accessibility
            4. Включите PushToTalk в списке
            5. Перезапустите приложение
            """
        }
    }
}

// MARK: - Supporting Types

/// Статус всех разрешений
public struct PermissionStatus {
    public let microphone: Bool
    public let accessibility: Bool

    public var allGranted: Bool {
        return microphone && accessibility
    }

    public var description: String {
        var status = "Permission Status:\n"
        status += "  - Microphone: \(microphone ? "✓" : "✗")\n"
        status += "  - Accessibility: \(accessibility ? "✓" : "✗")"
        return status
    }

    public init(microphone: Bool, accessibility: Bool) {
        self.microphone = microphone
        self.accessibility = accessibility
    }
}

/// Типы разрешений
public enum PermissionType {
    case microphone
    case accessibility
}
