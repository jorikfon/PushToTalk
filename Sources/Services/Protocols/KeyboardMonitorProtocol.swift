import Foundation
import Combine

/// Событие горячей клавиши
public enum HotkeyEvent: Sendable {
    case pressed
    /// Отпускание. submit = в момент отпускания был зажат Shift (и Shift не входит
    /// в саму комбинацию хоткея) → после вставки нужно нажать Enter (отправка в чат).
    case released(submit: Bool)
}

/// Протокол мониторинга глобальных горячих клавиш
/// Абстракция для keyboard monitoring позволяет легко подменять реализацию и создавать моки для тестирования
public protocol KeyboardMonitorProtocol: ObservableObject {
    // MARK: - Properties

    /// Нажата ли горячая клавиша в данный момент
    var isHotkeyPressed: Bool { get }

    // MARK: - AsyncStream API (Modern)

    /// Поток событий горячих клавиш (async/await)
    /// Используйте для асинхронной обработки событий нажатия/отпускания
    var hotkeyEvents: AsyncStream<HotkeyEvent> { get }

    // MARK: - Deprecated Callback API

    /// Callback при нажатии горячей клавиши
    /// - Warning: Deprecated. Используйте `hotkeyEvents` AsyncStream вместо callbacks
    @available(*, deprecated, message: "Use hotkeyEvents AsyncStream instead")
    var onHotkeyPress: (() -> Void)? { get set }

    /// Callback при отпускании горячей клавиши
    /// - Warning: Deprecated. Используйте `hotkeyEvents` AsyncStream вместо callbacks
    @available(*, deprecated, message: "Use hotkeyEvents AsyncStream instead")
    var onHotkeyRelease: (() -> Void)? { get set }

    // MARK: - Monitoring Control

    /// Начать мониторинг клавиатуры
    /// - Returns: true если мониторинг успешно запущен, false иначе
    @discardableResult
    func startMonitoring() -> Bool

    /// Остановить мониторинг клавиатуры
    func stopMonitoring()
}
