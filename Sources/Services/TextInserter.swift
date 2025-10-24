import Cocoa
import ApplicationServices

/// Сервис для вставки текста в текущую позицию курсора
/// Использует clipboard + Cmd+V симуляцию
public class TextInserter {
    private let pasteboard = NSPasteboard.general

    public init() {
        print("TextInserter: Инициализация")
    }

    /// Вставить текст в позицию курсора
    /// Использует временный clipboard и симуляцию Cmd+V
    public func insertTextAtCursor(_ text: String) {
        guard !text.isEmpty else {
            print("TextInserter: Попытка вставить пустой текст")
            return
        }

        print("TextInserter: Вставка текста (\(text.count) символов)")

        // Сохраняем старое содержимое clipboard
        let oldClipboardTypes = pasteboard.types ?? []
        var oldClipboardData: [NSPasteboard.PasteboardType: Data] = [:]

        for type in oldClipboardTypes {
            if let data = pasteboard.data(forType: type) {
                oldClipboardData[type] = data
            }
        }

        // Копируем новый текст в clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Симулируем Cmd+V
        simulatePaste()

        // Восстанавливаем старый clipboard через 300ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.restoreClipboard(oldClipboardData)
        }
    }

    /// Симуляция нажатия Cmd+V
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code для 'V' = 9
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        // Добавляем модификатор Command
        keyVDown?.flags = .maskCommand
        keyVUp?.flags = .maskCommand

        // Отправляем события
        keyVDown?.post(tap: .cghidEventTap)
        usleep(10000) // 10ms задержка
        keyVUp?.post(tap: .cghidEventTap)

        print("TextInserter: ✓ Cmd+V симулировано")
    }

    /// Восстановление старого содержимого clipboard
    private func restoreClipboard(_ oldData: [NSPasteboard.PasteboardType: Data]) {
        guard !oldData.isEmpty else {
            print("TextInserter: Нечего восстанавливать в clipboard")
            return
        }

        pasteboard.clearContents()

        for (type, data) in oldData {
            pasteboard.setData(data, forType: type)
        }

        print("TextInserter: ✓ Clipboard восстановлен")
    }

    // MARK: - Альтернативный метод через Accessibility API

    /// Вставка текста напрямую через Accessibility API (экспериментально)
    /// Работает не во всех приложениях
    public func insertTextViaAccessibility(_ text: String) -> Bool {
        guard let focusedElement = getFocusedElement() else {
            print("TextInserter: Не найден элемент в фокусе")
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
                print("TextInserter: ✓ Текст вставлен через Accessibility API")
                return true
            } else {
                print("TextInserter: ✗ Ошибка вставки через Accessibility API: \(setError.rawValue)")
            }
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
