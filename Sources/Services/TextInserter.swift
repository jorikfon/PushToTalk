import Cocoa
import ApplicationServices

/// Сервис для вставки текста в текущую позицию курсора
/// Использует clipboard + Cmd+V симуляцию
public class TextInserter {
    private let pasteboard = NSPasteboard.general

    public init() {
        LogManager.app.info("TextInserter инициализирован")
    }

    /// Вставить текст в позицию курсора
    /// Использует временный clipboard и симуляцию Cmd+V
    public func insertTextAtCursor(_ text: String) {
        guard !text.isEmpty else {
            LogManager.app.failure("Вставка текста", message: "Попытка вставить пустой текст")
            return
        }

        LogManager.app.begin("Вставка текста", details: "\(text.count) символов")

        // Сохраняем старое содержимое clipboard
        let oldClipboardTypes = pasteboard.types ?? []
        var oldClipboardData: [NSPasteboard.PasteboardType: Data] = [:]

        for type in oldClipboardTypes {
            if let data = pasteboard.data(forType: type) {
                oldClipboardData[type] = data
            }
        }

        LogManager.app.debug("Сохранено \(oldClipboardData.count) типов из clipboard")

        // Очищаем и копируем новый текст в clipboard
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        if !success {
            LogManager.app.failure("Копирование в clipboard", message: "Не удалось скопировать текст")
            return
        }

        LogManager.app.debug("Текст скопирован в clipboard")

        // Даем время системе обработать изменение clipboard
        usleep(50000) // 50ms

        // Симулируем Cmd+V
        simulatePaste()

        // Восстанавливаем старый clipboard через 500ms (увеличена задержка)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restoreClipboard(oldClipboardData)
        }

        LogManager.app.success("Вставка текста", details: "Cmd+V выполнено")
    }

    /// Симуляция нажатия Cmd+V
    private func simulatePaste() {
        // Проверяем Accessibility разрешения
        let trusted = AXIsProcessTrusted()
        if !trusted {
            LogManager.app.failure("Accessibility разрешения", message: "Приложение не имеет Accessibility разрешений для симуляции клавиш")
            LogManager.app.info("Откройте System Settings > Privacy & Security > Accessibility и добавьте PushToTalk")
            return
        }

        LogManager.app.debug("Accessibility разрешения: ✓ Получены")

        // Проверяем возможность создания событий
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            LogManager.app.failure("Создание CGEventSource", message: "Не удалось создать источник событий")
            return
        }

        // Key code для 'V' = 9
        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            LogManager.app.failure("Создание CGEvent", message: "Не удалось создать события клавиатуры")
            return
        }

        // Добавляем модификатор Command
        keyVDown.flags = .maskCommand
        keyVUp.flags = .maskCommand

        // Отправляем события
        keyVDown.post(tap: .cghidEventTap)
        LogManager.app.debug("Отправлено: Cmd+V down")

        usleep(50000) // 50ms задержка между down и up

        keyVUp.post(tap: .cghidEventTap)
        LogManager.app.debug("Отправлено: Cmd+V up")
    }

    /// Восстановление старого содержимого clipboard
    private func restoreClipboard(_ oldData: [NSPasteboard.PasteboardType: Data]) {
        guard !oldData.isEmpty else {
            LogManager.app.debug("Нечего восстанавливать в clipboard")
            return
        }

        pasteboard.clearContents()

        var restoredCount = 0
        for (type, data) in oldData {
            if pasteboard.setData(data, forType: type) {
                restoredCount += 1
            }
        }

        LogManager.app.success("Clipboard восстановлен", details: "\(restoredCount) типов")
    }

    // MARK: - Альтернативный метод через Accessibility API

    /// Вставка текста напрямую через Accessibility API (экспериментально)
    /// Работает не во всех приложениях
    /// ТРЕБУЕТ Accessibility разрешений!
    public func insertTextViaAccessibility(_ text: String) -> Bool {
        LogManager.app.begin("Вставка через Accessibility API")

        guard let focusedElement = getFocusedElement() else {
            LogManager.app.failure("Получение элемента в фокусе", message: "Не найден")
            return false
        }

        // Пытаемся вставить текст напрямую
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &value)

        if error == .success {
            let currentValue = value as? String ?? ""
            let newValue = currentValue + text

            let setError = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, newValue as CFTypeRef)

            if setError == .success {
                LogManager.app.success("Вставка через Accessibility API", details: "Успешно")
                return true
            } else {
                LogManager.app.failure("Вставка через Accessibility API", message: "OSStatus: \(setError.rawValue)")
            }
        } else {
            LogManager.app.failure("Чтение значения элемента", message: "OSStatus: \(error.rawValue)")
        }

        return false
    }

    /// Получение текущего элемента в фокусе
    private func getFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?

        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let appElement = focusedApp else {
            return nil
        }

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }
}
