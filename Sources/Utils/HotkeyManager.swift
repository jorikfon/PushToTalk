import Foundation
import Cocoa

/// Менеджер для управления горячими клавишами
/// Поддерживает любые комбинации клавиш с модификаторами через CGEventTap
public class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()

    @Published public var currentHotkey: Hotkey
    @Published public var isRecording: Bool = false

    private let storageKey = "pushToTalkHotkey"

    private init() {
        // F16 по умолчанию (инициализация перед loadHotkey)
        currentHotkey = Hotkey(name: "F16", keyCode: 106, displayName: "F16", modifiers: [])

        // Загружаем сохранённую горячую клавишу или используем F16 по умолчанию
        if let saved = loadHotkey() {
            currentHotkey = saved
        }

        LogManager.keyboard.info("HotkeyManager инициализирован с клавишей \(self.currentHotkey.displayName)")
    }

    /// Сохранение текущей горячей клавиши
    public func saveHotkey(_ hotkey: Hotkey) {
        // Проверяем валидность горячей клавиши
        guard isValidHotkey(hotkey) else {
            LogManager.keyboard.error("Попытка сохранить невалидную клавишу: \(hotkey.displayName)")
            return
        }

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
        let modifierOnlyKeys: Set<CGKeyCode> = [54, 55, 56, 58, 59, 60, 61, 62] // Command, Shift, Option, Control
        if modifierOnlyKeys.contains(hotkey.keyCode) && hotkey.modifiers.isEmpty {
            return false
        }

        // Запрещаем опасные системные комбинации
        let dangerousKeyCodes: Set<CGKeyCode> = [
            12,  // Q (Cmd+Q = Quit)
            13,  // W (Cmd+W = Close window)
            48,  // Tab (Cmd+Tab = App switcher)
            49   // Space (может конфликтовать с Spotlight)
        ]

        if hotkey.modifiers.contains(.maskCommand) && dangerousKeyCodes.contains(hotkey.keyCode) {
            return false
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

            // Проверяем валидность загруженной клавиши
            guard isValidHotkey(hotkey) else {
                LogManager.keyboard.error("Загруженная клавиша невалидна: \(hotkey.displayName)")
                LogManager.keyboard.info("Сброс на клавишу по умолчанию: F16")

                // Удаляем недопустимую настройку
                UserDefaults.standard.removeObject(forKey: storageKey)
                return nil
            }

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
}

/// Структура для представления горячей клавиши
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let keyCode: CGKeyCode
    public let displayName: String
    public let modifiers: CGEventFlags

    public init(name: String, keyCode: CGKeyCode, displayName: String, modifiers: CGEventFlags = []) {
        self.name = name
        self.keyCode = keyCode
        self.displayName = displayName
        self.modifiers = modifiers
    }

    // Реализация Codable
    enum CodingKeys: String, CodingKey {
        case name, keyCode, displayName, modifiers
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
        displayName = try container.decode(String.self, forKey: .displayName)
        let modifiersRaw = try container.decodeIfPresent(UInt64.self, forKey: .modifiers) ?? 0
        modifiers = CGEventFlags(rawValue: modifiersRaw)
    }

    // Реализация Equatable
    public static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }
}

/// Расширение для получения названия клавиши по key code
public extension CGKeyCode {
    var displayName: String {
        switch self {
        // Function keys
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"

        // Letters
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"

        // Numbers
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"

        // Special keys
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 117: return "Forward Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        default: return "Key \(self)"
        }
    }
}

/// Расширение для форматирования модификаторов
public extension CGEventFlags {
    var displayName: String {
        var result: [String] = []

        if contains(.maskControl) { result.append("⌃") }
        if contains(.maskAlternate) { result.append("⌥") }
        if contains(.maskShift) { result.append("⇧") }
        if contains(.maskCommand) { result.append("⌘") }

        return result.joined()
    }
}

/// Notification name для изменения hotkey
public extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}
