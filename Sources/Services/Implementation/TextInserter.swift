import Cocoa
import ApplicationServices

/// Сервис для вставки текста в текущую позицию курсора
/// Использует clipboard + Cmd+V симуляцию
public class TextInserter: TextInserterProtocol {
    private let pasteboard = NSPasteboard.general

    public init() {
        LogManager.app.info("TextInserter инициализирован")
    }

    /// Вставить текст в позицию курсора
    /// Использует временный clipboard и симуляцию Cmd+V.
    /// - Parameter pressReturnAfter: нажать Enter после вставки (отправка в чат)
    public func insertTextAtCursor(_ text: String, pressReturnAfter: Bool) {
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

        // Дожидаемся, пока пользователь физически отпустит модификаторы (Shift при
        // submit-режиме, сам fn-хоткей, Cmd/Ctrl/Opt). Иначе синтетические Cmd+V и
        // Return «слипаются» с зажатыми модификаторами на HID-уровне: получается
        // Cmd+Shift+V, fn+… (оконные шорткаты macOS Tahoe — разворот/сворачивание
        // окна) и т.п. Фиксированная задержка не спасала, когда Shift держат всю
        // отправку, — поэтому ждём именно отпускания (с таймаутом).
        waitForModifiersToClear()
        usleep(40000) // короткая стабилизация после отпускания

        // Симулируем Cmd+V
        simulatePaste()

        // Режим «отправить»: после вставки жмём Enter (например, отправка в чат)
        if pressReturnAfter {
            usleep(120000) // даём вставке примениться перед Enter
            simulateReturn()
        }

        // Восстанавливаем старый clipboard через 500ms (увеличена задержка)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restoreClipboard(oldClipboardData)
        }

        LogManager.app.success("Вставка текста", details: "Cmd+V выполнено\(pressReturnAfter ? " + Enter" : "")")
    }

    /// Симуляция нажатия Return (Enter) — для режима «отправить в чат»
    private func simulateReturn() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            LogManager.app.failure("Создание CGEventSource", message: "Не удалось создать источник для Enter")
            return
        }
        // Key code для Return = 36
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) else {
            LogManager.app.failure("Создание CGEvent", message: "Не удалось создать события Enter")
            return
        }
        // На случай, если Shift всё ещё зажат, — дожидаемся отпускания и явно
        // обнуляем флаги, чтобы ушёл чистый Return, а не Shift+Return (перевод
        // строки вместо отправки) или иной модифицированный вариант.
        waitForModifiersToClear()
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        usleep(20000) // 20ms между down и up
        up.post(tap: .cghidEventTap)
        LogManager.app.debug("Отправлено: Return (отправка в чат)")
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

    /// Дожидается отпускания физических модификаторов (Shift/Cmd/Ctrl/Opt/fn),
    /// чтобы синтетические нажатия (Cmd+V, Return) не «слипались» с зажатыми
    /// клавишами на HID-уровне. Ограничено таймаутом, чтобы не зависнуть, если
    /// клавишу действительно удерживают.
    private func waitForModifiersToClear(timeoutMs: Int = 600) {
        let watched: CGEventFlags = [.maskShift, .maskCommand, .maskControl, .maskAlternate, .maskSecondaryFn]
        let stepUs: UInt32 = 15000
        var waitedUs = 0
        while waitedUs < timeoutMs * 1000 {
            let held = CGEventSource.flagsState(.combinedSessionState).intersection(watched)
            if held.isEmpty { return }
            usleep(stepUs)
            waitedUs += Int(stepUs)
        }
        let stillHeld = CGEventSource.flagsState(.combinedSessionState).intersection(watched)
        if !stillHeld.isEmpty {
            LogManager.app.debug("Модификаторы всё ещё зажаты после ожидания (rawFlags=\(stillHeld.rawValue)); вставляю как есть")
        }
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
