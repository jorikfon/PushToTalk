import Cocoa
import Carbon
import Combine

/// Контекст для CGEventTap callback (custom hotkey mode)
class HotkeyTapContext {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
    var continuation: AsyncStream<HotkeyEvent>.Continuation?
    var isPressed: Bool = false

    init(keyCode: CGKeyCode, modifiers: CGEventFlags, continuation: AsyncStream<HotkeyEvent>.Continuation?) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.continuation = continuation
    }
}

/// Глобальный мониторинг горячих клавиш
/// Поддерживает два режима:
/// 1. Preset (Carbon API) - F13-F19, НЕ требует Accessibility разрешения
/// 2. Custom (CGEventTap) - любые комбинации клавиш, требует Accessibility разрешения
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
    private var eventTap: CFMachPort?
    private var customEventTap: CFMachPort?  // Для custom hotkey режима
    private var tapContext: HotkeyTapContext?  // Контекст для custom tap callback
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
        LogManager.keyboard.begin("Запуск мониторинга", details: "клавиша \(hotkey.displayName) (режим: \(hotkey.source))")

        // Выбираем режим мониторинга в зависимости от source
        switch hotkey.source {
        case .preset:
            return startPresetMonitoring(hotkey: hotkey)
        case .custom:
            return startCustomMonitoring(hotkey: hotkey)
        }
    }

    /// Запуск мониторинга в preset режиме (Carbon API для F13-F19)
    private func startPresetMonitoring(hotkey: Hotkey) -> Bool {
        LogManager.keyboard.info("Preset режим: Carbon API (не требует Accessibility для F-клавиш)")

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

        // Создаём Event Tap для полной блокировки клавиши (требует Accessibility)
        setupEventTap(for: hotkey.keyCode)

        isMonitoring = true
        LogManager.keyboard.success("Preset мониторинг запущен", details: "Carbon API с эксклюзивным захватом для \(hotkey.displayName)")

        return true
    }

    /// Запуск мониторинга в custom режиме (CGEventTap для любых комбинаций)
    private func startCustomMonitoring(hotkey: Hotkey) -> Bool {
        // Проверяем Accessibility разрешение (ОБЯЗАТЕЛЬНО для custom режима)
        let trusted = AXIsProcessTrusted()
        if !trusted {
            LogManager.keyboard.error("❌ Custom режим требует Accessibility разрешение")
            LogManager.keyboard.info("💡 Добавьте PushToTalk в System Settings → Privacy & Security → Accessibility")
            return false
        }

        LogManager.keyboard.info("Custom режим: CGEventTap (Accessibility разрешение предоставлено)")

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        // Создаём контекст для передачи в callback
        tapContext = HotkeyTapContext(
            keyCode: hotkey.keyCode,
            modifiers: hotkey.modifiers,
            continuation: eventContinuation
        )

        // Получаем unsafe pointer на контекст
        let contextPtr = Unmanaged.passUnretained(tapContext!).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return KeyboardMonitor.handleCustomEventTap(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: contextPtr
        ) else {
            LogManager.keyboard.error("❌ Не удалось создать CGEventTap для custom hotkey")
            tapContext = nil
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        customEventTap = tap
        isMonitoring = true
        LogManager.keyboard.success("Custom мониторинг запущен", details: "CGEventTap для \(hotkey.displayName)")

        return true
    }

    /// Callback для CGEventTap (custom hotkey режим)
    private static func handleCustomEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        // Получаем контекст
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }

        let context = Unmanaged<HotkeyTapContext>.fromOpaque(refcon).takeUnretainedValue()

        let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = event.flags

        // Проверяем совпадение keyCode
        guard eventKeyCode == context.keyCode else {
            return Unmanaged.passRetained(event)
        }

        // Проверяем совпадение модификаторов (если они есть)
        if !context.modifiers.isEmpty {
            // Маска для проверки только нужных модификаторов
            let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            let eventRelevantModifiers = eventModifiers.intersection(relevantFlags)
            let requiredModifiers = context.modifiers.intersection(relevantFlags)

            guard eventRelevantModifiers == requiredModifiers else {
                return Unmanaged.passRetained(event)
            }
        }

        // Это наша горячая клавиша! Обрабатываем нажатие/отпускание
        if type == .keyDown && !context.isPressed {
            context.isPressed = true
            LogManager.keyboard.info("Custom горячая клавиша нажата")

            // Отправляем событие в AsyncStream
            context.continuation?.yield(.pressed)

            // Вызываем deprecated callback
            DispatchQueue.main.async {
                KeyboardMonitor.shared?.onHotkeyPress?()
                KeyboardMonitor.shared?.isHotkeyPressed = true
            }

            // Блокируем событие
            return nil
        } else if type == .keyUp && context.isPressed {
            context.isPressed = false
            LogManager.keyboard.info("Custom горячая клавиша отпущена")

            // Отправляем событие в AsyncStream
            context.continuation?.yield(.released)

            // Вызываем deprecated callback
            DispatchQueue.main.async {
                KeyboardMonitor.shared?.onHotkeyRelease?()
                KeyboardMonitor.shared?.isHotkeyPressed = false
            }

            // Блокируем событие
            return nil
        }

        // Пропускаем событие
        return Unmanaged.passRetained(event)
    }

    /// Создаёт CGEventTap для полной блокировки клавиши (требует Accessibility)
    private func setupEventTap(for keyCode: UInt16) {
        // Проверяем Accessibility разрешение
        let trusted = AXIsProcessTrusted()
        if !trusted {
            LogManager.keyboard.warning("⚠️ Accessibility не предоставлено - клавиша может вызывать системные действия (Emoji picker)")
            LogManager.keyboard.info("💡 Добавьте PushToTalk в System Settings → Privacy & Security → Accessibility")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        // Создаём указатель для передачи keyCode в callback
        let keyCodePtr = UnsafeMutablePointer<UInt16>.allocate(capacity: 1)
        keyCodePtr.pointee = keyCode

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)

                // Получаем сохранённый keyCode
                guard let keyCodePtr = refcon?.assumingMemoryBound(to: UInt16.self) else {
                    return Unmanaged.passRetained(event)
                }
                let targetKeyCode = Int64(keyCodePtr.pointee)

                // Блокируем нашу клавишу
                if eventKeyCode == targetKeyCode {
                    return nil  // Полностью съедаем событие
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: UnsafeMutableRawPointer(keyCodePtr)
        ) else {
            keyCodePtr.deallocate()
            LogManager.keyboard.error("❌ Не удалось создать Event Tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        LogManager.keyboard.success("✅ Event Tap активирован - клавиша полностью блокирована от системы")
    }


    /// Остановить мониторинг клавиатуры
    public func stopMonitoring() {
        guard isMonitoring else { return }

        LogManager.keyboard.begin("Остановка мониторинга")

        // Отменяем регистрацию горячей клавиши (preset режим)
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        // Удаляем event handler (preset режим)
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        // Отключаем Event Tap для блокировки (preset режим)
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        // Отключаем Custom Event Tap (custom режим)
        if let customEventTap = customEventTap {
            CGEvent.tapEnable(tap: customEventTap, enable: false)
            CFMachPortInvalidate(customEventTap)
            self.customEventTap = nil
        }

        // Очищаем контекст custom tap
        tapContext = nil

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
