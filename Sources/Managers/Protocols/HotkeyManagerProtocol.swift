import Foundation
import Combine
import Cocoa

/// Протокол менеджера для управления горячими клавишами
/// Абстракция для hotkey management позволяет легко подменять реализацию и создавать моки для тестирования
public protocol HotkeyManagerProtocol: ObservableObject {
    // MARK: - Properties

    /// Текущая горячая клавиша
    var currentHotkey: Hotkey { get set }

    /// Идёт ли процесс записи новой горячей клавиши
    var isRecording: Bool { get set }

    /// Key code текущей горячей клавиши
    var currentKeyCode: CGKeyCode { get }

    // MARK: - Hotkey Management

    /// Сохранить горячую клавишу
    /// - Parameter hotkey: Новая горячая клавиша
    func saveHotkey(_ hotkey: Hotkey)

    /// Проверить валидность горячей клавиши
    /// - Parameter hotkey: Горячая клавиша для проверки
    /// - Returns: true если клавиша валидна, false иначе
    func isValidHotkey(_ hotkey: Hotkey) -> Bool
}
