//
//  HotkeyManager.swift
//  PushToTalk
//
//  Менеджер для управления горячими клавишами
//  Поддерживает любые комбинации клавиш с модификаторами через CGEventTap
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

    private let storageKey = "pushToTalkHotkey"  // Legacy key (for backwards compatibility)
    private let presetStorageKey = "pushToTalkPresetHotkey"
    private let customStorageKey = "pushToTalkCustomHotkey"
    private let modeStorageKey = "pushToTalkHotkeyMode"

    // MARK: - Computed Properties (Protocol)

    public var currentKeyCode: CGKeyCode {
        return currentHotkey.keyCode
    }

    // MARK: - Initialization

    public init() {
        // F16 по умолчанию (инициализация перед loadHotkey)
        currentHotkey = Hotkey(name: "F16", keyCode: 106, displayName: "F16", modifiers: [], source: .preset)

        // Миграция: проверяем legacy storage key
        if let legacyHotkey = loadLegacyHotkey() {
            LogManager.keyboard.info("Мигрируем legacy hotkey в новое хранилище")
            // Сохраняем в preset storage
            saveHotkeyToStorage(legacyHotkey, key: presetStorageKey)
            // Удаляем legacy key
            UserDefaults.standard.removeObject(forKey: storageKey)
            currentHotkey = legacyHotkey
        } else {
            // Загружаем текущий режим
            let currentMode = loadCurrentMode()

            // Загружаем сохранённую горячую клавишу для текущего режима
            if let saved = loadHotkey(for: currentMode) {
                currentHotkey = saved
            }
        }

        LogManager.keyboard.info("HotkeyManager инициализирован с клавишей \(self.currentHotkey.displayName) (режим: \(self.currentHotkey.source))")
    }

    // MARK: - Protocol Methods

    /// Сохранение текущей горячей клавиши
    public func saveHotkey(_ hotkey: Hotkey) {
        // Проверяем валидность горячей клавиши
        guard isValidHotkey(hotkey) else {
            LogManager.keyboard.error("Попытка сохранить невалидную клавишу: \(hotkey.displayName)")
            return
        }

        currentHotkey = hotkey

        // Сохраняем в соответствующее хранилище в зависимости от source
        let storageKey = hotkey.source == .preset ? presetStorageKey : customStorageKey
        saveHotkeyToStorage(hotkey, key: storageKey)

        // Сохраняем текущий режим
        UserDefaults.standard.set(hotkey.source.rawValue, forKey: modeStorageKey)

        LogManager.keyboard.success("Горячая клавиша сохранена", details: "\(hotkey.displayName) (режим: \(hotkey.source))")

        // Уведомляем об изменении (для обновления KeyboardMonitor)
        NotificationCenter.default.post(name: .hotkeyDidChange, object: hotkey)
    }

    /// Сохранение preset горячей клавиши
    public func savePresetHotkey(_ hotkey: Hotkey) {
        var presetHotkey = hotkey
        // Убедимся что source установлен в .preset
        if hotkey.source != .preset {
            presetHotkey = Hotkey(
                name: hotkey.name,
                keyCode: hotkey.keyCode,
                displayName: hotkey.displayName,
                modifiers: hotkey.modifiers,
                source: .preset
            )
        }
        saveHotkey(presetHotkey)
    }

    /// Сохранение custom горячей клавиши
    public func saveCustomHotkey(_ hotkey: Hotkey) {
        var customHotkey = hotkey
        // Убедимся что source установлен в .custom
        if hotkey.source != .custom {
            customHotkey = Hotkey(
                name: hotkey.name,
                keyCode: hotkey.keyCode,
                displayName: hotkey.displayName,
                modifiers: hotkey.modifiers,
                source: .custom
            )
        }
        saveHotkey(customHotkey)
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

    // MARK: - Private Methods

    /// Загрузка сохранённой горячей клавиши для указанного режима
    public func loadHotkey(for source: HotkeySource) -> Hotkey? {
        let storageKey = source == .preset ? presetStorageKey : customStorageKey
        return loadHotkeyFromStorage(key: storageKey)
    }

    /// Загрузка текущего режима из UserDefaults
    private func loadCurrentMode() -> HotkeySource {
        guard let modeString = UserDefaults.standard.string(forKey: modeStorageKey),
              let mode = HotkeySource(rawValue: modeString) else {
            return .preset  // По умолчанию preset режим
        }
        return mode
    }

    /// Загрузка legacy hotkey (для миграции)
    private func loadLegacyHotkey() -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let hotkey = try decoder.decode(Hotkey.self, from: data)

            // Проверяем валидность загруженной клавиши
            guard isValidHotkey(hotkey) else {
                LogManager.keyboard.error("Legacy клавиша невалидна: \(hotkey.displayName)")
                UserDefaults.standard.removeObject(forKey: storageKey)
                return nil
            }

            LogManager.keyboard.success("Legacy клавиша загружена для миграции", details: hotkey.displayName)
            return hotkey
        } catch {
            LogManager.keyboard.failure("Загрузка legacy клавиши", error: error)
            return nil
        }
    }

    /// Общий метод загрузки горячей клавиши из указанного storage key
    private func loadHotkeyFromStorage(key: String) -> Hotkey? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let hotkey = try decoder.decode(Hotkey.self, from: data)

            // Проверяем валидность загруженной клавиши
            guard isValidHotkey(hotkey) else {
                LogManager.keyboard.error("Загруженная клавиша невалидна: \(hotkey.displayName)")
                LogManager.keyboard.info("Удаляем невалидную настройку из \(key)")

                // Удаляем недопустимую настройку
                UserDefaults.standard.removeObject(forKey: key)
                return nil
            }

            LogManager.keyboard.success("Горячая клавиша загружена", details: "\(hotkey.displayName) из \(key)")
            return hotkey
        } catch {
            LogManager.keyboard.failure("Загрузка горячей клавиши из \(key)", error: error)
            return nil
        }
    }

    /// Общий метод сохранения горячей клавиши в указанный storage key
    private func saveHotkeyToStorage(_ hotkey: Hotkey, key: String) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(hotkey)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            LogManager.keyboard.failure("Сохранение горячей клавиши в \(key)", error: error)
        }
    }
}

// MARK: - HotkeySource

/// Источник горячей клавиши (определяет какой API использовать для мониторинга)
public enum HotkeySource: String, Codable {
    case preset    // F13-F19 через Carbon API (не требует Accessibility)
    case custom    // Произвольная комбинация через CGEventTap (требует Accessibility)
}

// MARK: - Hotkey

/// Структура для представления горячей клавиши
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let keyCode: CGKeyCode
    public let displayName: String
    public let modifiers: CGEventFlags
    public let source: HotkeySource

    public init(name: String, keyCode: CGKeyCode, displayName: String, modifiers: CGEventFlags = [], source: HotkeySource = .preset) {
        self.name = name
        self.keyCode = keyCode
        self.displayName = displayName
        self.modifiers = modifiers
        self.source = source
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, keyCode, displayName, modifiers, source
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(source, forKey: .source)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        keyCode = try container.decode(CGKeyCode.self, forKey: .keyCode)
        displayName = try container.decode(String.self, forKey: .displayName)
        let modifiersRaw = try container.decodeIfPresent(UInt64.self, forKey: .modifiers) ?? 0
        modifiers = CGEventFlags(rawValue: modifiersRaw)
        // Backwards compatibility: default to .preset for old saved hotkeys
        source = try container.decodeIfPresent(HotkeySource.self, forKey: .source) ?? .preset
    }

    // MARK: - Equatable

    public static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers && lhs.source == rhs.source
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
