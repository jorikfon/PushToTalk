import Cocoa
import Carbon
import Combine

/// Глобальный мониторинг горячих клавиш через Carbon API (RegisterEventHotKey)
/// НЕ требует Accessibility разрешения для F13-F19
/// Автоматически блокирует системный Emoji picker для F16
public class KeyboardMonitor: KeyboardMonitorProtocol, ObservableObject {
    @Published public var isHotkeyPressed = false

    // MARK: - AsyncStream API

    /// Поток событий горячих клавиш
    public var hotkeyEvents: AsyncStream<HotkeyEvent> {
        AsyncStream { continuation in
            // Сохраняем continuation для отправки событий
            self.eventContinuation = continuation

            // Cleanup при завершении stream
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.eventContinuation = nil
            }
        }
    }

    // MARK: - Deprecated Callback API

    public var onHotkeyPress: (() -> Void)?
    public var onHotkeyRelease: (() -> Void)?

    // MARK: - Private Properties

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isMonitoring = false
    private var cancellables = Set<AnyCancellable>()

    /// Continuation для AsyncStream событий
    private var eventContinuation: AsyncStream<HotkeyEvent>.Continuation?

    // Static reference для callback
    private static var shared: KeyboardMonitor?

    // MARK: - Initialization

    public init() {
        LogManager.keyboard.info("Инициализация KeyboardMonitor (Carbon API)")
        KeyboardMonitor.shared = self

        // Подписываемся на изменения hotkey
        NotificationCenter.default.publisher(for: .hotkeyDidChange)
            .sink { [weak self] notification in
                guard let newHotkey = notification.object as? Hotkey else { return }
                LogManager.keyboard.info("Обнаружено изменение hotkey на: \(newHotkey.displayName)")
                self?.restartMonitoring()
            }
            .store(in: &cancellables)
    }

    /// Начать мониторинг клавиатуры
    public func startMonitoring() -> Bool {
        // Защита от повторного запуска
        guard !isMonitoring else {
            LogManager.keyboard.info("Мониторинг уже запущен, пропускаем")
            return true
        }

        let hotkey = HotkeyManager.shared.currentHotkey
        LogManager.keyboard.begin("Запуск мониторинга", details: "клавиша \(hotkey.displayName) (keyCode: \(hotkey.keyCode))")

        // Carbon API НЕ требует Accessibility для F13-F19
        LogManager.keyboard.info("Carbon API не требует Accessibility разрешения для F-клавиш")

        // Регистрируем Carbon Event Handler для нажатия И отпускания
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                return KeyboardMonitor.handleCarbonEvent(nextHandler: nextHandler, event: event, userData: userData)
            },
            2,  // Теперь 2 типа событий
            &eventTypes,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            LogManager.keyboard.error("Не удалось установить Carbon Event Handler: \(status)")
            return false
        }

        // Регистрируем горячую клавишу
        let hotkeyID = EventHotKeyID(signature: OSType(0x50545400), id: 1) // 'PTT\0'
        let modifiers = carbonModifiers(from: hotkey.modifiers)

        let registerStatus = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),  // Эксклюзивный захват - блокируем системные обработчики
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            LogManager.keyboard.error("Не удалось зарегистрировать горячую клавишу: \(registerStatus)")
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            return false
        }

        isMonitoring = true
        LogManager.keyboard.success("Мониторинг запущен", details: "Carbon API для \(hotkey.displayName)")

        return true
    }

    /// Остановить мониторинг клавиатуры
    public func stopMonitoring() {
        guard isMonitoring else { return }

        LogManager.keyboard.begin("Остановка мониторинга")

        // Отменяем регистрацию горячей клавиши
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        // Удаляем event handler
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        isMonitoring = false
        LogManager.keyboard.success("Мониторинг остановлен")
    }

    /// Перезапустить мониторинг (при смене hotkey)
    private func restartMonitoring() {
        LogManager.keyboard.info("Перезапуск мониторинга с новой hotkey")
        stopMonitoring()
        _ = startMonitoring()
    }

    // MARK: - Carbon Event Handler

    private static func handleCarbonEvent(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let monitor = KeyboardMonitor.shared else {
            return OSStatus(eventNotHandledErr)
        }

        // Определяем тип события (нажатие или отпускание)
        var eventKind: UInt32 = 0
        GetEventParameter(
            event,
            UInt32(kEventParamKeyboardType),
            UInt32(typeUInt32),
            nil,
            MemoryLayout<UInt32>.size,
            nil,
            &eventKind
        )

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return OSStatus(eventNotHandledErr)
        }

        // Проверяем что это наша горячая клавиша
        if hotKeyID.signature == OSType(0x50545400) && hotKeyID.id == 1 {
            let hotkey = HotkeyManager.shared.currentHotkey

            // Carbon Event имеет структуру: eventClass + eventKind
            // Мы зарегистрировали 2 типа событий: kEventHotKeyPressed и kEventHotKeyReleased
            // Проверим текущее состояние isHotkeyPressed чтобы понять это Press или Release

            if !monitor.isHotkeyPressed {
                // Это событие нажатия (потому что кнопка еще не нажата)
                monitor.isHotkeyPressed = true
                LogManager.keyboard.info("Горячая клавиша нажата: \(hotkey.displayName)")

                // Отправляем событие в AsyncStream
                monitor.eventContinuation?.yield(.pressed)

                // Вызываем deprecated callback для backwards compatibility
                DispatchQueue.main.async {
                    monitor.onHotkeyPress?()
                }
            } else {
                // Это событие отпускания (потому что кнопка уже нажата)
                monitor.isHotkeyPressed = false
                LogManager.keyboard.info("Горячая клавиша отпущена: \(hotkey.displayName)")

                // Отправляем событие в AsyncStream
                monitor.eventContinuation?.yield(.released)

                // Вызываем deprecated callback для backwards compatibility
                DispatchQueue.main.async {
                    monitor.onHotkeyRelease?()
                }
            }

            // ВАЖНО: CallNextEventHandler НЕ вызываем, чтобы съесть событие полностью
            // Возвращаем noErr = событие обработано И не передается дальше по цепочке
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    // MARK: - Helper Methods

    /// Конвертация CGEventFlags в Carbon модификаторы
    private func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.maskCommand) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.maskShift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.maskAlternate) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.maskControl) {
            modifiers |= UInt32(controlKey)
        }

        return modifiers
    }

    deinit {
        stopMonitoring()
        KeyboardMonitor.shared = nil
        LogManager.keyboard.info("KeyboardMonitor деинициализирован")
    }
}
