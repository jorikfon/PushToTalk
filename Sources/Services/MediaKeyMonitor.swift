import Foundation
import ApplicationServices
import CoreGraphics
import AppKit

/// Сервис для мониторинга медиа-кнопок (EarPods, наушники, клавиатура)
/// Использует CGEventTap для перехвата системных медиа-событий
/// ТРЕБУЕТ: Accessibility разрешений
public class MediaKeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Колбэки для событий (push-to-talk стиль)
    public var onPlayPausePress: (() -> Void)?   // Нажата кнопка → начало записи
    public var onPlayPauseRelease: (() -> Void)? // Отпущена кнопка → остановка записи

    // Медиа-клавиши коды (NX_KEYTYPE_*)
    private let NX_KEYTYPE_PLAY = 16  // Play/Pause
    private let NX_KEYTYPE_FAST = 17  // Next track
    private let NX_KEYTYPE_REWIND = 18  // Previous track

    public init() {
        LogManager.keyboard.info("MediaKeyMonitor: Инициализация")
    }

    /// Запустить мониторинг медиа-кнопок
    public func startMonitoring() -> Bool {
        LogManager.keyboard.begin("Запуск мониторинга медиа-кнопок")

        // Проверяем Accessibility разрешения
        let trusted = AXIsProcessTrusted()
        if !trusted {
            LogManager.keyboard.failure("Мониторинг медиа-кнопок", message: "Требуются Accessibility разрешения")
            return false
        }

        // Создаём event tap для системных событий
        // CGEventType 14 = NSEvent.EventType.systemDefined
        let eventMask: CGEventMask = (1 << 14)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<MediaKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            LogManager.keyboard.failure("Создание event tap", message: "Не удалось создать CGEventTap")
            return false
        }

        eventTap = tap

        // Добавляем в run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        LogManager.keyboard.success("Мониторинг медиа-кнопок запущен")
        return true
    }

    /// Остановить мониторинг медиа-кнопок
    public func stopMonitoring() {
        LogManager.keyboard.info("Остановка мониторинга медиа-кнопок")

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            eventTap = nil
            runLoopSource = nil
        }
    }

    // MARK: - Event Handlers

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Получаем NSEvent для доступа к системным событиям
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }

        // Проверяем что это системное медиа-событие
        guard nsEvent.type == NSEvent.EventType.systemDefined,
              nsEvent.subtype.rawValue == 8 else {  // subtype 8 = AUX control changed (media keys)
            return Unmanaged.passRetained(event)
        }

        // Извлекаем keyCode и flags из NSEvent.data1
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyDown = ((keyFlags & 0xFF00) >> 8) == 0xA

        // Проверяем что это Play/Pause кнопка
        if keyCode == NX_KEYTYPE_PLAY {
            if keyDown {
                LogManager.keyboard.info("📱 Media Key: Play/Pause DOWN")
                handlePlayPausePress()
            } else {
                LogManager.keyboard.info("📱 Media Key: Play/Pause UP")
                handlePlayPauseRelease()
            }

            // Блокируем событие, чтобы не передавалось дальше (не запускалась музыка)
            return nil
        }

        // Пропускаем остальные события
        return Unmanaged.passRetained(event)
    }

    private func handlePlayPausePress() {
        // Нажата кнопка → начало записи
        onPlayPausePress?()
    }

    private func handlePlayPauseRelease() {
        // Отпущена кнопка → остановка записи
        onPlayPauseRelease?()
    }

    deinit {
        stopMonitoring()
        LogManager.keyboard.info("MediaKeyMonitor деинициализирован")
    }
}
