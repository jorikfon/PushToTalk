import Foundation
import AVFoundation

/// Менеджер разрешений для всех необходимых системных доступов
/// Carbon API для hotkeys НЕ требует Accessibility разрешений - нужен только доступ к микрофону
public class PermissionManager {
    public static let shared = PermissionManager()

    private init() {
        LogManager.permissions.info("Инициализация PermissionManager")
    }

    // MARK: - Microphone Permissions

    /// Проверка разрешения на микрофон
    public func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            LogManager.permissions.success("Микрофон разрешен")
            return true
        case .notDetermined:
            LogManager.permissions.info("Запрос разрешения на микрофон")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if granted {
                LogManager.permissions.success("Микрофон разрешен пользователем")
            } else {
                LogManager.permissions.failure("Микрофон отклонен", message: "Пользователь отказал в доступе")
            }
            return granted
        case .denied, .restricted:
            LogManager.permissions.failure("Микрофон недоступен", message: "Отказано или ограничено")
            return false
        @unknown default:
            LogManager.permissions.error("Микрофон: неизвестный статус авторизации")
            return false
        }
    }

    // MARK: - Check All Permissions

    /// Проверка всех необходимых разрешений
    public func checkAllPermissions() async -> PermissionStatus {
        LogManager.permissions.begin("Проверка разрешений")
        let micPermission = await checkMicrophonePermission()

        let status = PermissionStatus(microphone: micPermission)
        LogManager.permissions.info("\(status.description)")

        return status
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
            5. Перезапустите приложение
            """
        }
    }
}

// MARK: - Supporting Types

/// Статус всех разрешений
public struct PermissionStatus {
    public let microphone: Bool

    public var allGranted: Bool {
        return microphone
    }

    public var description: String {
        var status = "Permission Status:\n"
        status += "  - Microphone: \(microphone ? "✓" : "✗")"
        return status
    }

    public init(microphone: Bool) {
        self.microphone = microphone
    }
}

/// Типы разрешений
public enum PermissionType {
    case microphone
}
