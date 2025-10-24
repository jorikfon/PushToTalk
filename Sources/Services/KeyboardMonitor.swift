import Cocoa
import Combine
import ApplicationServices

/// Глобальный мониторинг клавиши F16 (keyCode 127)
/// Требует Accessibility разрешений
public class KeyboardMonitor: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @Published public var isF16Pressed = false

    public var onF16Press: (() -> Void)?
    public var onF16Release: (() -> Void)?

    public init() {
        print("KeyboardMonitor: Инициализация")
    }

    /// Проверка Accessibility разрешений
    public func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrusted()

        if !trusted {
            print("KeyboardMonitor: Accessibility разрешения не предоставлены")
            // Запрашиваем разрешения с показом диалога
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            print("KeyboardMonitor: Accessibility разрешения предоставлены")
        }

        return trusted
    }

    /// Начать мониторинг клавиатуры
    public func startMonitoring() -> Bool {
        guard checkAccessibilityPermissions() else {
            print("KeyboardMonitor: Невозможно начать мониторинг без Accessibility разрешений")
            return false
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("KeyboardMonitor: ✗ Не удалось создать event tap")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("KeyboardMonitor: ✓ Мониторинг клавиатуры запущен")
        return true
    }

    /// Остановить мониторинг клавиатуры
    public func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
            print("KeyboardMonitor: Мониторинг остановлен")
        }
    }

    /// Обработка события клавиатуры
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // F16 key = 127 на macOS
        if keyCode == 127 {
            if type == .keyDown && !isF16Pressed {
                isF16Pressed = true
                print("KeyboardMonitor: F16 нажата")

                DispatchQueue.main.async { [weak self] in
                    self?.onF16Press?()
                }

                // Блокируем событие, чтобы F16 не вызывала системные действия
                // Возвращаем пустое событие
                if let nullEvent = CGEvent(source: nil) {
                    return Unmanaged.passUnretained(nullEvent)
                }
            } else if type == .keyUp && isF16Pressed {
                isF16Pressed = false
                print("KeyboardMonitor: F16 отпущена")

                DispatchQueue.main.async { [weak self] in
                    self?.onF16Release?()
                }

                // Блокируем событие
                if let nullEvent = CGEvent(source: nil) {
                    return Unmanaged.passUnretained(nullEvent)
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stopMonitoring()
    }
}
