  //
//  HotkeyManager.swift
//  PushToTalk
//
//  Менеджер для управления горячими клавишами
//  Использует CGEventTap для всех hotkeys (требует Accessibility permissions)
//

import Foundation
import Cocoa

public class HotkeyManager: HotkeyManagerProtocol, ObservableObject {

    // MARK: - Backwards Compatibility (deprecated)

    /// ⚠️ DEPRECATED: Используйте ServiceContainer.shared.hotkeyManager
    /// Временная совместимость для существующего кода
    @available(*, deprecated, message: "Use ServiceContainer.shared.hotkeyManager instead")
    public static var shared: HotkeyManager {
        return ServiceContainer.shared.hotkeyManager as! HotkeyManager
    }

    // MARK: - Published Properties (Protocol)

    @Published public var currentHotkey: Hotkey
    @Published public var isRecording: Bool = false

    // MARK: - Private Properties

    private let storageKey = "pushToTalkHotkey"

    /// Опасные системные комбинации
    private static let dangerousKeyCodes: Set<UInt16> = [12, 13, 48] // Q, W, Tab

    // MARK: - Computed Properties (Protocol)

    public var currentKeyCode: CGKeyCode {
        return currentHotkey.keyCode
    }

    // MARK: - Default Hotkey

    public static let defaultHotkey = Hotkey(name: "F16", keyCode: 106, displayName: "F16", modifiers: [])

    // MARK: - Initialization

    public init() {
        // F16 по умолчанию (инициализация перед loadHotkey)
        currentHotkey = HotkeyManager.defaultHotkey

        // Загружаем сохранённую горячую клавишу
        if let saved = loadHotkey() {
            currentHotkey = saved
        }

        // Миграция со старых форматов хранения
        migrateOldStorageIfNeeded()

        LogManager.keyboard.info("HotkeyManager инициализирован: клавиша=\(self.currentHotkey.displayName)")
    }

    // MARK: - Protocol Methods

    /// Сохранение текущей горячей клавиши
    public func saveHotkey(_ hotkey: Hotkey) {
        guard isValidHotkey(hotkey) else {
            LogManager.keyboard.error("Попытка сохранить невалидную клавишу: \(hotkey.displayName)")
            return
        }

        currentHotkey = hotkey

        do {
            let data = try JSONEncoder().encode(hotkey)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            LogManager.keyboard.failure("Сохранение горячей клавиши", error: error)
            return
        }

        LogManager.keyboard.success("Горячая клавиша сохранена", details: hotkey.displayName)

        // Уведомляем об изменении (для обновления KeyboardMonitor)
        NotificationCenter.default.post(name: .hotkeyDidChange, object: hotkey)
    }

    /// Проверка валидности горячей клавиши
    public func isValidHotkey(_ hotkey: Hotkey) -> Bool {
        // Запрещаем modifier-only клавиши
        let modifierOnlyKeys: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
        if modifierOnlyKeys.contains(hotkey.keyCode) {
            return false
        }

        // Запрещаем опасные системные комбинации (Cmd+Q, Cmd+W, Cmd+Tab)
        if hotkey.modifiers.contains(.maskCommand) && HotkeyManager.dangerousKeyCodes.contains(hotkey.keyCode) {
            return false
        }

        return true
    }

    /// Загрузка сохранённой горячей клавиши
    public func loadHotkey() -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            let hotkey = try JSONDecoder().decode(Hotkey.self, from: data)

            guard isValidHotkey(hotkey) else {
                LogManager.keyboard.error("Загруженная клавиша невалидна: \(hotkey.displayName)")
                UserDefaults.standard.removeObject(forKey: storageKey)
                return nil
            }

            return hotkey
        } catch {
            LogManager.keyboard.failure("Загрузка горячей клавиши", error: error)
            return nil
        }
    }

    // MARK: - Private Methods

    /// Миграция со старых форматов хранения (preset/custom режимы)
    private func migrateOldStorageIfNeeded() {
        let oldPresetKey = "pushToTalkPresetHotkey"
        let oldCustomKey = "pushToTalkCustomHotkey"
        let oldModeKey = "pushToTalkHotkeyMode"

        // Проверяем, есть ли старые ключи
        var migratedHotkey: Hotkey?

        // Пытаемся загрузить из старого preset ключа
        if let presetData = UserDefaults.standard.data(forKey: oldPresetKey) {
            migratedHotkey = try? JSONDecoder().decode(Hotkey.self, from: presetData)
        }

        // Если нет preset, пытаемся загрузить из custom
        if migratedHotkey == nil, let customData = UserDefaults.standard.data(forKey: oldCustomKey) {
            migratedHotkey = try? JSONDecoder().decode(Hotkey.self, from: customData)
        }

        // Если нашли старую hotkey - мигрируем
        if let oldHotkey = migratedHotkey {
            // Конвертируем в новый формат (без source)
            let newHotkey = Hotkey(
                name: oldHotkey.name,
                keyCode: oldHotkey.keyCode,
                displayName: oldHotkey.displayName,
                modifiers: oldHotkey.modifiers
            )

            do {
                let data = try JSONEncoder().encode(newHotkey)
                UserDefaults.standard.set(data, forKey: storageKey)
                currentHotkey = newHotkey

                // Удаляем старые ключи
                UserDefaults.standard.removeObject(forKey: oldPresetKey)
                UserDefaults.standard.removeObject(forKey: oldCustomKey)
                UserDefaults.standard.removeObject(forKey: oldModeKey)

                LogManager.keyboard.info("Миграция горячей клавиши из старого формата: \(newHotkey.displayName)")
            } catch {
                LogManager.keyboard.failure("Миграция горячей клавиши", error: error)
            }
        }
    }
}

// MARK: - Hotkey

/// Структура для представления горячей клавиши
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let keyCode: CGKeyCode
    public let displayName: String
    public let modifiers: CGEventFlags

    /// Порог длительности нажатия для hold detection (в секундах)
    /// 0 = disabled (нажатие срабатывает сразу)
    /// > 0 = требуется удержание клавиши на указанное время
    public let holdDurationThreshold: TimeInterval

    public init(name: String, keyCode: CGKeyCode, displayName: String, modifiers: CGEventFlags = [], holdDurationThreshold: TimeInterval = 0) {
        self.name = name
        self.keyCode = keyCode
        self.displayName = displayName
        self.modifiers = modifiers
        self.holdDurationThreshold = holdDurationThreshold
    }

    // MARK: - Computed Properties

    /// Требуется ли долгое нажатие для активации
    public var requiresHold: Bool {
        return holdDurationThreshold > 0
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, keyCode, displayName, modifiers, holdDurationThreshold
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(holdDurationThreshold, forKey: .holdDurationThreshold)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
        displayName = try container.decode(String.self, forKey: .displayName)
        let modifiersRaw = try container.decodeIfPresent(UInt64.self, forKey: .modifiers) ?? 0
        modifiers = CGEventFlags(rawValue: modifiersRaw)
        holdDurationThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .holdDurationThreshold) ?? 0
    }

    // MARK: - Equatable

    public static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers && lhs.holdDurationThreshold == rhs.holdDurationThreshold
    }
}

// MARK: - CGKeyCode Extensions

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
        case 50: return "`"
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

// MARK: - CGEventFlags Extensions

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

// MARK: - Notifications

/// Notification name для изменения hotkey
public extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}
