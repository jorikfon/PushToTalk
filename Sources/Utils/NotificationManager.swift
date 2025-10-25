import Foundation
import UserNotifications
import AppKit

/// Менеджер для отправки user notifications
public class NotificationManager: NSObject {
    public static let shared = NotificationManager()

    @Published public var permissionGranted = false

    private override init() {
        super.init()
        print("NotificationManager: Инициализация")
    }

    /// Запрос разрешения на отправку уведомлений
    public func requestPermission() async -> Bool {
        // Проверяем что bundle доступен
        guard Bundle.main.bundleIdentifier != nil else {
            print("NotificationManager: ⚠️ Bundle недоступен, пропускаем запрос разрешений")
            return false
        }

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.permissionGranted = granted
            }

            if granted {
                print("NotificationManager: ✓ Разрешение на уведомления получено")
            } else {
                print("NotificationManager: ⚠️ Разрешение на уведомления отклонено")
            }

            return granted
        } catch {
            print("NotificationManager: ✗ Ошибка запроса разрешения: \(error)")
            return false
        }
    }

    /// Проверка текущего статуса разрешений
    public func checkPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let granted = settings.authorizationStatus == .authorized

        await MainActor.run {
            self.permissionGranted = granted
        }

        return granted
    }

    /// Отправка уведомления об успешной транскрипции
    public func showTranscriptionNotification(text: String, duration: TimeInterval? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"

        // Обрезаем длинный текст для уведомления
        if text.count > 100 {
            content.body = String(text.prefix(97)) + "..."
        } else {
            content.body = text
        }

        content.sound = .default
        content.categoryIdentifier = "TRANSCRIPTION"

        // Добавляем информацию о длительности, если доступна
        if let duration = duration {
            content.subtitle = String(format: "Processed in %.1fs", duration)
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: ✗ Ошибка отправки уведомления: \(error)")
            } else {
                print("NotificationManager: ✓ Уведомление о транскрипции отправлено")
            }
        }
    }

    /// Отправка уведомления об ошибке
    public func showErrorNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "PushToTalk Error"
        content.body = message
        content.sound = .defaultCritical
        content.categoryIdentifier = "ERROR"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: ✗ Ошибка отправки уведомления об ошибке: \(error)")
            } else {
                print("NotificationManager: ✓ Уведомление об ошибке отправлено")
            }
        }
    }

    /// Отправка информационного уведомления
    public func showInfoNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "INFO"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: ✗ Ошибка отправки информационного уведомления: \(error)")
            } else {
                print("NotificationManager: ✓ Информационное уведомление отправлено")
            }
        }
    }

    /// Очистка всех доставленных уведомлений
    public func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("NotificationManager: ✓ Все уведомления очищены")
    }

    /// Настройка категорий уведомлений
    public func setupNotificationCategories() {
        // Проверяем что bundle доступен (защита от краша при запуске через командную строку)
        guard Bundle.main.bundleIdentifier != nil else {
            print("NotificationManager: ⚠️ Bundle недоступен, пропускаем настройку уведомлений")
            return
        }

        let transcriptionCategory = UNNotificationCategory(
            identifier: "TRANSCRIPTION",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let errorCategory = UNNotificationCategory(
            identifier: "ERROR",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let infoCategory = UNNotificationCategory(
            identifier: "INFO",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            transcriptionCategory,
            errorCategory,
            infoCategory
        ])

        print("NotificationManager: ✓ Категории уведомлений настроены")
    }
}

/// Расширение для облегчения работы с уведомлениями
public extension NotificationManager {
    /// Комбинированная отправка: звук + уведомление (успешная транскрипция)
    func notifyTranscriptionSuccess(text: String, duration: TimeInterval? = nil, playSound: Bool = true) {
        if playSound {
            SoundManager.shared.play(.transcriptionSuccess)
        }

        if permissionGranted {
            showTranscriptionNotification(text: text, duration: duration)
        }
    }

    /// Комбинированная отправка: звук + уведомление (ошибка)
    func notifyError(message: String, playSound: Bool = true) {
        if playSound {
            SoundManager.shared.play(.transcriptionError)
        }

        if permissionGranted {
            showErrorNotification(message: message)
        }
    }
}
