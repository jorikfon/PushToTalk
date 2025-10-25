import Foundation
import Carbon

/// Менеджер для управления горячими клавишами
/// Поддерживает настройку кнопки активации (по умолчанию F16)
public class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()

    @Published public var currentHotkey: Hotkey
    @Published public var isRecording: Bool = false

    private let storageKey = "pushToTalkHotkey"

    // Список доступных клавиш
    public let availableHotkeys: [Hotkey] = [
        Hotkey(name: "F13", keyCode: 105, displayName: "F13"),
        Hotkey(name: "F14", keyCode: 107, displayName: "F14"),
        Hotkey(name: "F15", keyCode: 113, displayName: "F15"),
        Hotkey(name: "F16", keyCode: 106, displayName: "F16 (Default)"),
        Hotkey(name: "F17", keyCode: 64, displayName: "F17"),
        Hotkey(name: "F18", keyCode: 79, displayName: "F18"),
        Hotkey(name: "F19", keyCode: 80, displayName: "F19"),
        Hotkey(name: "RightCommand", keyCode: 54, displayName: "Right ⌘"),
        Hotkey(name: "RightOption", keyCode: 61, displayName: "Right ⌥"),
        Hotkey(name: "RightControl", keyCode: 62, displayName: "Right ⌃")
    ]

    private init() {
        // F16 по умолчанию (инициализация перед loadHotkey)
        currentHotkey = Hotkey(name: "F16", keyCode: 106, displayName: "F16 (Default)")

        // Загружаем сохранённую горячую клавишу или используем F16 по умолчанию
        if let saved = loadHotkey() {
            currentHotkey = saved
        }

        LogManager.keyboard.info("HotkeyManager инициализирован с клавишей \(self.currentHotkey.displayName)")
    }

    /// Сохранение текущей горячей клавиши
    public func saveHotkey(_ hotkey: Hotkey) {
        currentHotkey = hotkey

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(hotkey)
            UserDefaults.standard.set(data, forKey: storageKey)
            LogManager.keyboard.success("Горячая клавиша сохранена", details: hotkey.displayName)

            // Уведомляем об изменении (для обновления KeyboardMonitor)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: hotkey)
        } catch {
            LogManager.keyboard.failure("Сохранение горячей клавиши", error: error)
        }
    }

    /// Проверка валидности hotkey (чтобы не использовать системные комбинации)
    public func isValidHotkey(_ hotkey: Hotkey) -> Bool {
        // Запрещаем чисто modifier keys без основной клавиши
        if hotkey.name.contains("(incomplete)") {
            return false
        }

        // Запрещаем системные комбинации (например, Cmd+Q, Cmd+W)
        let dangerousKeys = ["Q", "W", "Tab", "Space"]
        if hotkey.name.contains("⌘") {
            for key in dangerousKeys {
                if hotkey.displayName.contains(key) {
                    return false
                }
            }
        }

        return true
    }

    /// Загрузка сохранённой горячей клавиши
    private func loadHotkey() -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let hotkey = try decoder.decode(Hotkey.self, from: data)
            LogManager.keyboard.success("Горячая клавиша загружена", details: hotkey.displayName)
            return hotkey
        } catch {
            LogManager.keyboard.failure("Загрузка горячей клавиши", error: error)
            return nil
        }
    }

    /// Получение key code для текущей горячей клавиши
    public var currentKeyCode: CGKeyCode {
        return currentHotkey.keyCode
    }

    /// Поиск горячей клавиши по key code
    public func findHotkey(byKeyCode keyCode: CGKeyCode) -> Hotkey? {
        return availableHotkeys.first { $0.keyCode == keyCode }
    }

    /// Проверка является ли клавиша функциональной (F13-F19)
    public func isFunctionKey(_ hotkey: Hotkey) -> Bool {
        return hotkey.name.hasPrefix("F")
    }
}

/// Структура для представления горячей клавиши
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let keyCode: CGKeyCode
    public let displayName: String

    public init(name: String, keyCode: CGKeyCode, displayName: String) {
        self.name = name
        self.keyCode = keyCode
        self.displayName = displayName
    }

    // Реализация Codable
    enum CodingKeys: String, CodingKey {
        case name, keyCode, displayName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(displayName, forKey: .displayName)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
        displayName = try container.decode(String.self, forKey: .displayName)
    }

    // Реализация Equatable (нужно для автоматической реализации)
    public static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode
    }
}

/// Расширение для получения названия клавиши по key code
public extension CGKeyCode {
    var displayName: String {
        switch self {
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"
        case 54: return "Right ⌘"
        case 61: return "Right ⌥"
        case 62: return "Right ⌃"
        default: return "Key \(self)"
        }
    }
}

/// Notification name для изменения hotkey
public extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}
