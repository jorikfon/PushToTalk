import AppKit

/// Сервис для отображения системных алертов и уведомлений
/// Инкапсулирует логику показа NSAlert и других UI элементов
public final class AlertService {

    // MARK: - Initialization

    public init() {}

    // MARK: - Error Alerts

    /// Показать алерт с ошибкой
    /// - Parameters:
    ///   - message: Текст ошибки
    ///   - title: Заголовок (опционально, по умолчанию из Strings)
    public func showError(_ message: String, title: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title ?? Strings.App.name + " " + Strings.Errors.title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: Strings.Buttons.ok)
            alert.runModal()
        }
    }

    // MARK: - Info Alerts

    /// Показать информационный алерт
    /// - Parameters:
    ///   - title: Заголовок алерта
    ///   - message: Информационное сообщение
    public func showInfo(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: Strings.Buttons.ok)
            alert.runModal()
        }
    }

    // MARK: - Confirmation Alerts

    /// Показать алерт с подтверждением
    /// - Parameters:
    ///   - title: Заголовок алерта
    ///   - message: Сообщение с вопросом
    ///   - confirmButtonTitle: Текст кнопки подтверждения (по умолчанию "OK")
    ///   - cancelButtonTitle: Текст кнопки отмены (по умолчанию "Cancel")
    /// - Returns: true если пользователь нажал кнопку подтверждения
    @discardableResult
    public func showConfirmation(
        _ title: String,
        message: String,
        confirmButtonTitle: String = Strings.Buttons.ok,
        cancelButtonTitle: String = Strings.Buttons.cancel
    ) -> Bool {
        var result = false

        DispatchQueue.main.sync {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: confirmButtonTitle)
            alert.addButton(withTitle: cancelButtonTitle)

            let response = alert.runModal()
            result = (response == .alertFirstButtonReturn)
        }

        return result
    }

    // MARK: - Warning Alerts

    /// Показать предупреждающий алерт
    /// - Parameters:
    ///   - title: Заголовок предупреждения
    ///   - message: Сообщение с предупреждением
    public func showWarning(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: Strings.Buttons.ok)
            alert.runModal()
        }
    }

    // MARK: - System Notifications

    /// Показать системное уведомление (User Notification)
    /// - Parameters:
    ///   - title: Заголовок уведомления
    ///   - body: Текст уведомления
    ///   - identifier: Уникальный идентификатор (опционально)
    public func showNotification(title: String, body: String, identifier: String? = nil) {
        // TODO: Реализовать через UNUserNotificationCenter когда потребуется
        // Пока используем простой alert
        LogManager.app.info("Notification: \(title) - \(body)")
    }
}
