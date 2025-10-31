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

        // ВАЖНО: Задержка перед Cmd+V чтобы система "забыла" про F16
        // Иначе F16 + Cmd может интерпретироваться как системный шорткат (Emoji picker)
        usleep(200000) // 200ms задержка для сброса состояния клавиатуры

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
}
