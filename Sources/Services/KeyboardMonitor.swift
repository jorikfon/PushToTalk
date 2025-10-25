import Cocoa
import Combine
import Carbon

/// Глобальный мониторинг горячих клавиш через Carbon API (RegisterEventHotKey)
/// Carbon API более надежен для функциональных клавиш (F13-F19) и НЕ требует Accessibility разрешений
/// Поддерживает настраиваемые клавиши через HotkeyManager
public class KeyboardMonitor: ObservableObject {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var cancellables = Set<AnyCancellable>()

    @Published public var isHotkeyPressed = false

    public var onHotkeyPress: (() -> Void)?
    public var onHotkeyRelease: (() -> Void)?

    // Получаем текущий keyCode из HotkeyManager
    private var currentKeyCode: CGKeyCode {
        return HotkeyManager.shared.currentKeyCode
    }

    // Уникальный signature для идентификации наших hotkeys
    private let hotkeySignature = OSType(0x50545448)  // 'PTTH' = PushToTalk Hotkey

    public init() {
        LogManager.keyboard.info("Инициализация KeyboardMonitor (Carbon API)")

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
        let hotkey = HotkeyManager.shared.currentHotkey
        LogManager.keyboard.begin("Запуск мониторинга", details: "клавиша \(hotkey.displayName) (keyCode: \(hotkey.keyCode))")

        // Создаем EventTypeSpec для press и release событий
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        // Устанавливаем обработчик событий
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userData).takeUnretainedValue()
                return monitor.handleCarbonEvent(event: event)
            },
            eventTypes.count,
            &eventTypes,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )

        guard status == noErr else {
            LogManager.keyboard.failure("Не удалось установить event handler", message: "OSStatus: \(status)")
            return false
        }

        // Регистрируем hotkey
        guard registerHotkey() else {
            LogManager.keyboard.failure("Не удалось зарегистрировать hotkey", message: hotkey.displayName)
            return false
        }

        LogManager.keyboard.success("Мониторинг запущен", details: "ожидаю нажатия \(hotkey.displayName)")
        return true
    }

    /// Остановить мониторинг клавиатуры
    public func stopMonitoring() {
        LogManager.keyboard.begin("Остановка мониторинга")

        // Отменяем регистрацию hotkey
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            LogManager.keyboard.debug("Hotkey отменен")
        }

        // Удаляем обработчик событий
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
            LogManager.keyboard.debug("Event handler удален")
        }

        LogManager.keyboard.success("Мониторинг остановлен")
    }

    /// Перезапустить мониторинг (при смене hotkey)
    private func restartMonitoring() {
        LogManager.keyboard.info("Перезапуск мониторинга с новой hotkey")
        stopMonitoring()
        _ = startMonitoring()
    }

    // MARK: - Private Methods

    /// Регистрация hotkey в Carbon Event Manager
    private func registerHotkey() -> Bool {
        let hotkey = HotkeyManager.shared.currentHotkey

        // Конвертируем модификаторы (для функциональных клавиш F13-F19 модификаторы не нужны)
        let modifiers = convertModifiers(for: hotkey)

        // Создаем EventHotKeyID
        let hotkeyID = EventHotKeyID(signature: hotkeySignature, id: UInt32(hotkey.keyCode))

        // Регистрируем hotkey
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,  // options
            &hotKeyRef
        )

        if status == noErr {
            LogManager.keyboard.debug("RegisterEventHotKey success: keyCode=\(hotkey.keyCode), modifiers=\(modifiers)")
            return true
        } else {
            LogManager.keyboard.error("RegisterEventHotKey failed: OSStatus=\(status)")
            return false
        }
    }

    /// Конвертация модификаторов для Carbon API
    private func convertModifiers(for hotkey: Hotkey) -> UInt32 {
        // Для функциональных клавиш (F13-F19) модификаторы не нужны
        if HotkeyManager.shared.isFunctionKey(hotkey) {
            return 0
        }

        // Для модификаторов (Right Cmd, Right Option, Right Control)
        // используем соответствующие флаги
        var modifiers: UInt32 = 0

        switch hotkey.name {
        case "RightCommand":
            modifiers = UInt32(cmdKey)
        case "RightOption":
            modifiers = UInt32(optionKey)
        case "RightControl":
            modifiers = UInt32(controlKey)
        default:
            break
        }

        LogManager.keyboard.debug("Модификаторы для \(hotkey.name): \(modifiers)")
        return modifiers
    }

    /// Обработка Carbon события
    private func handleCarbonEvent(event: EventRef?) -> OSStatus {
        guard let event = event else {
            return OSStatus(eventNotHandledErr)
        }

        // Получаем тип события
        let eventKind = Int(GetEventKind(event))

        // Получаем hotkey ID
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard status == noErr else {
            LogManager.keyboard.debug("Не удалось получить EventHotKeyID: OSStatus=\(status)")
            return OSStatus(eventNotHandledErr)
        }

        // Проверяем что это наш hotkey
        guard hotkeyID.signature == hotkeySignature else {
            return OSStatus(eventNotHandledErr)
        }

        let hotkey = HotkeyManager.shared.currentHotkey

        // Обрабатываем нажатие/отпускание
        if eventKind == kEventHotKeyPressed {
            if !isHotkeyPressed {
                isHotkeyPressed = true
                LogManager.keyboard.info("Горячая клавиша нажата: \(hotkey.displayName)")

                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyPress?()
                }
            }
        } else if eventKind == kEventHotKeyReleased {
            if isHotkeyPressed {
                isHotkeyPressed = false
                LogManager.keyboard.info("Горячая клавиша отпущена: \(hotkey.displayName)")

                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyRelease?()
                }
            }
        }

        return noErr
    }

    deinit {
        stopMonitoring()
        LogManager.keyboard.info("KeyboardMonitor деинициализирован")
    }
}
