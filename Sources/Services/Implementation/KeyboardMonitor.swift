import Cocoa
import Combine

/// Контекст для CGEventTap callback
/// Используется как refcon для передачи данных в C-style callback
private class HotkeyTapContext {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
    let holdDurationThreshold: TimeInterval
    weak var monitor: KeyboardMonitor?

    var isPressed: Bool = false
    var keyDownTime: Date?
    var holdTimer: DispatchWorkItem?
    var isHoldActivated: Bool = false

    init(keyCode: CGKeyCode, modifiers: CGEventFlags, holdDurationThreshold: TimeInterval, monitor: KeyboardMonitor) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.holdDurationThreshold = holdDurationThreshold
        self.monitor = monitor
    }

    /// Требуется ли долгое нажатие для активации
    var requiresHold: Bool {
        return holdDurationThreshold > 0
    }
}

/// Глобальный мониторинг горячих клавиш через CGEventTap
/// Требует Accessibility permissions для перехвата клавиш
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

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapContext: HotkeyTapContext?
    private var isMonitoring = false
    private var cancellables = Set<AnyCancellable>()

    /// Continuation для AsyncStream событий
    fileprivate var eventContinuation: AsyncStream<HotkeyEvent>.Continuation?

    /// Текущая hotkey (читается из HotkeyManager)
    private var currentHotkey: Hotkey {
        return (ServiceContainer.shared.hotkeyManager as! HotkeyManager).currentHotkey
    }

    // MARK: - Initialization

    public init() {
        LogManager.keyboard.info("Инициализация KeyboardMonitor (CGEventTap)")

        // Подписываемся на изменения hotkey
        NotificationCenter.default.publisher(for: .hotkeyDidChange)
            .sink { [weak self] notification in
                guard let newHotkey = notification.object as? Hotkey else { return }
                LogManager.keyboard.info("Обнаружено изменение hotkey на: \(newHotkey.displayName)")
                self?.restartMonitoring()
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring Control

    /// Начать мониторинг клавиатуры
    public func startMonitoring() -> Bool {
        guard !isMonitoring else {
            LogManager.keyboard.info("Мониторинг уже запущен, пропускаем")
            return true
        }

        let hotkey = currentHotkey
        LogManager.keyboard.begin("Запуск мониторинга", details: "клавиша=\(hotkey.displayName) (keyCode: \(hotkey.keyCode))")

        // Проверяем Accessibility
        guard AXIsProcessTrusted() else {
            LogManager.keyboard.error("CGEventTap: Accessibility не разрешен. Горячие клавиши недоступны.")
            return false
        }

        // Создаём контекст для callback
        let context = HotkeyTapContext(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, holdDurationThreshold: hotkey.holdDurationThreshold, monitor: self)
        self.tapContext = context

        // Указатель на контекст для C-style callback
        let contextPtr = Unmanaged.passRetained(context).toOpaque()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let ctx = Unmanaged<HotkeyTapContext>.fromOpaque(refcon).takeUnretainedValue()

                // Если tap был отключён системой — включаем обратно
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let monitor = ctx.monitor {
                        LogManager.keyboard.info("CGEventTap: tap был отключён, переактивируем")
                        if let tap = monitor.eventTap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passRetained(event)
                }

                let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

                // Проверяем совпадение keyCode
                guard eventKeyCode == ctx.keyCode else {
                    return Unmanaged.passRetained(event)
                }

                // Проверяем модификаторы (если заданы)
                if !ctx.modifiers.isEmpty {
                    let eventFlags = event.flags
                    // Маска для пользовательских модификаторов (без device-independent flags)
                    let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
                    let eventMods = eventFlags.intersection(relevantMask)
                    let targetMods = ctx.modifiers.intersection(relevantMask)

                    guard eventMods == targetMods else {
                        return Unmanaged.passRetained(event)
                    }
                }

                // Обрабатываем press/release с hold detection
                if type == .keyDown && !ctx.isPressed {
                    ctx.isPressed = true
                    ctx.keyDownTime = Date()

                    if ctx.requiresHold {
                        // Hold mode: ждём порог перед активацией
                        let holdTimer = DispatchWorkItem { [weak ctx] in
                            guard let ctx = ctx else { return }
                            // Порог достигнут - активируем hold
                            ctx.isHoldActivated = true
                            DispatchQueue.main.async {
                                ctx.monitor?.isHotkeyPressed = true
                                ctx.monitor?.eventContinuation?.yield(.pressed)
                                ctx.monitor?.onHotkeyPress?()
                                LogManager.keyboard.info("Горячая клавиша активирована (hold): \(ctx.keyCode.displayName)")
                            }
                        }
                        ctx.holdTimer = holdTimer
                        DispatchQueue.main.asyncAfter(deadline: .now() + ctx.holdDurationThreshold, execute: holdTimer)
                        LogManager.keyboard.debug("Ожидание hold threshold: \(ctx.holdDurationThreshold)s для \(ctx.keyCode.displayName)")
                        return nil // Поглощаем keyDown (ждём hold или короткое нажатие)
                    } else {
                        // Instant mode: активация сразу
                        DispatchQueue.main.async {
                            ctx.monitor?.isHotkeyPressed = true
                            ctx.monitor?.eventContinuation?.yield(.pressed)
                            ctx.monitor?.onHotkeyPress?()
                            LogManager.keyboard.info("Горячая клавиша нажата: \(ctx.keyCode.displayName)")
                        }
                        return nil // Поглощаем событие
                    }
                } else if type == .keyUp && ctx.isPressed {
                    ctx.isPressed = false

                    if ctx.requiresHold {
                        if ctx.isHoldActivated {
                            // Hold был активирован - обрабатываем release
                            ctx.isHoldActivated = false
                            DispatchQueue.main.async {
                                ctx.monitor?.isHotkeyPressed = false
                                ctx.monitor?.eventContinuation?.yield(.released)
                                ctx.monitor?.onHotkeyRelease?()
                                LogManager.keyboard.info("Горячая клавиша отпущена (hold): \(ctx.keyCode.displayName)")
                            }
                            return nil // Поглощаем keyUp
                        } else {
                            // Короткое нажатие - отменяем таймер и пропускаем событие
                            ctx.holdTimer?.cancel()
                            ctx.holdTimer = nil
                            LogManager.keyboard.debug("Короткое нажатие: пропускаем keyDown+keyUp для \(ctx.keyCode.displayName)")

                            // Программно генерируем keyDown + keyUp для passthrough
                            DispatchQueue.main.async {
                                guard let source = CGEventSource(stateID: .hidSystemState) else { return }
                                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: ctx.keyCode, keyDown: true),
                                   let keyUp = CGEvent(keyboardEventSource: source, virtualKey: ctx.keyCode, keyDown: false) {
                                    keyDown.flags = ctx.modifiers
                                    keyUp.flags = ctx.modifiers
                                    keyDown.post(tap: .cghidEventTap)
                                    usleep(50000) // 50ms между down и up
                                    keyUp.post(tap: .cghidEventTap)
                                    LogManager.keyboard.debug("Программно сгенерированы keyDown+keyUp для \(ctx.keyCode.displayName)")
                                }
                            }
                            return nil // Поглощаем keyUp (уже сгенерировали events)
                        }
                    } else {
                        // Instant mode: release сразу
                        DispatchQueue.main.async {
                            ctx.monitor?.isHotkeyPressed = false
                            ctx.monitor?.eventContinuation?.yield(.released)
                            ctx.monitor?.onHotkeyRelease?()
                            LogManager.keyboard.info("Горячая клавиша отпущена: \(ctx.keyCode.displayName)")
                        }
                        return nil // Поглощаем событие
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: contextPtr
        ) else {
            LogManager.keyboard.error("CGEventTap: не удалось создать event tap")
            Unmanaged<HotkeyTapContext>.fromOpaque(contextPtr).release()
            self.tapContext = nil
            return false
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isMonitoring = true
        LogManager.keyboard.success("Мониторинг запущен", details: "CGEventTap для \(hotkey.displayName)")
        return true
    }

    /// Остановить мониторинг клавиатуры
    public func stopMonitoring() {
        guard isMonitoring else { return }

        LogManager.keyboard.begin("Остановка мониторинга")

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        // Освобождаем контекст
        if let context = tapContext {
            // Release retained reference from passRetained
            Unmanaged.passUnretained(context).release()
            tapContext = nil
        }

        isMonitoring = false
        isHotkeyPressed = false
        LogManager.keyboard.success("Мониторинг остановлен")
    }

    /// Перезапустить мониторинг (при смене hotkey)
    private func restartMonitoring() {
        LogManager.keyboard.info("Перезапуск мониторинга с новой hotkey")
        stopMonitoring()
        _ = startMonitoring()
    }

    deinit {
        stopMonitoring()
        LogManager.keyboard.info("KeyboardMonitor деинициализирован")
    }
}
