---
name: m-refactor-hotkey-key-constraints
branch: feature/m-refactor-hotkey-key-constraints
status: in-progress
created: 2026-02-17
---

# Hotkey Key Constraints Refactor

## Problem/Goal

В текущей реализации KeyboardMonitor использует CGEventTap и разрешает любые клавиши в качестве hotkey. Это создаёт конфликты с текстовым вводом:

**Проблема**: Если пользователь выбирает обычную клавишу (например тильда `` ` ``) без модификатора, при нажатии:
1. macOS Text Input System (TSM/IME) **уже обработала символ** до нашего CGEventTap
2. Символ может напечататься в активное поле
3. Hold detection пытался решить это, но создаёт задержку и тоже ненадёжен

**Решение**: Ограничить выбор hotkeys только клавишами, которые не производят текстовый ввод:
- **F1-F19** — функциональные клавиши, не производят текст
- **Любая клавиша + модификатор (⌘/⌥/⌃)** — модификатор блокирует текстовый ввод

## Success Criteria

- [ ] Убрана hold detection логика (откат)
- [ ] `isValidHotkey()` запрещает regular keys без модификаторов
- [ ] F1-F19 разрешены без модификаторов
- [ ] HotkeyRecorderView не принимает regular key без модификатора (показывает ошибку/игнорирует)
- [ ] UI объясняет ограничение пользователю
- [ ] Компиляция без ошибок

## Current State (что сейчас в коде)

> **ВАЖНО**: Перед этим заданием были выполнены два рефакторинга:
> 1. Удалён весь Carbon API, KeyboardMonitor работает только через CGEventTap
> 2. Добавлен hold detection (который нужно откатить)

### Ключевые файлы:

**`Sources/Managers/Implementation/HotkeyManager.swift`**
- Struct `Hotkey` содержит `holdDurationThreshold: TimeInterval` и `requiresHold: Bool` → **нужно убрать**
- `isValidHotkey()` сейчас разрешает любые клавиши → **нужно добавить ограничение**
- `HotkeySource` enum удалён, `Hotkey` не имеет `.source`
- Один `storageKey = "pushToTalkHotkey"`, миграция из старых preset/custom ключей реализована

**`Sources/Services/Implementation/KeyboardMonitor.swift`**
- `HotkeyTapContext` содержит `holdTimer`, `keyDownTime`, `isHoldActivated` → **нужно убрать**
- Hold detection логика в CGEventTap callback (≈50 строк if/else) → **нужно упростить**
- CGEventTap с `.headInsertEventTap` + `.defaultTap` (может поглощать события)

**`Sources/Presentation/Views/Settings/HotkeySettingsView.swift`**
- Содержит "Hold Detection" SettingsCard с Toggle и Slider → **нужно убрать**

## Implementation Plan

### Step 1: Откат Hold Detection (HotkeyManager.swift)

Убрать из struct `Hotkey`:
```swift
// УДАЛИТЬ:
public let holdDurationThreshold: TimeInterval

public init(..., holdDurationThreshold: TimeInterval = 0) { ... }

public var requiresHold: Bool { ... }

// Из CodingKeys:
case holdDurationThreshold

// Из encode():
try container.encode(holdDurationThreshold, forKey: .holdDurationThreshold)

// Из init(from decoder:):
holdDurationThreshold = try container.decodeIfPresent(TimeInterval.self, ...) ?? 0

// Из ==:
&& lhs.holdDurationThreshold == rhs.holdDurationThreshold
```

---

### Step 2: Добавить ограничение ключей в `isValidHotkey()`

```swift
/// Коды F-клавиш (F1-F19), разрешённых без модификаторов
private static let functionKeyCodes: Set<CGKeyCode> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, // F1-F12
    105, 107, 113, 106, 64, 79, 80                           // F13-F19
]

public func isValidHotkey(_ hotkey: Hotkey) -> Bool {
    // Запрещаем modifier-only клавиши
    let modifierOnlyKeys: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
    if modifierOnlyKeys.contains(hotkey.keyCode) { return false }

    // F-клавиши разрешены без модификаторов
    if HotkeyManager.functionKeyCodes.contains(hotkey.keyCode) { return true }

    // Regular keys (буквы, цифры, символы) — ОБЯЗАТЕЛЕН модификатор
    // Разрешаем ⌘ / ⌥ / ⌃ (но НЕ только ⇧ — Shift+A это просто заглавная буква)
    let meaningfulModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
    guard !hotkey.modifiers.intersection(meaningfulModifiers).isEmpty else {
        return false // regular key без ⌘/⌥/⌃ — запрещено
    }

    // Запрещаем опасные системные комбинации (Cmd+Q, Cmd+W, Cmd+Tab)
    let dangerousKeyCodes: Set<UInt16> = [12, 13, 48]
    if hotkey.modifiers.contains(.maskCommand) && dangerousKeyCodes.contains(hotkey.keyCode) {
        return false
    }

    return true
}
```

---

### Step 3: Откат Hold Detection (KeyboardMonitor.swift)

**В `HotkeyTapContext` убрать:**
```swift
// УДАЛИТЬ из class:
var keyDownTime: Date?
var holdTimer: DispatchWorkItem?
var isHoldActivated: Bool = false

// УДАЛИТЬ init параметр:
let holdDurationThreshold: TimeInterval

// УДАЛИТЬ computed property:
var requiresHold: Bool { ... }
```

**В `startMonitoring()` убрать из создания context:**
```swift
// БЫЛО:
HotkeyTapContext(keyCode: ..., modifiers: ..., holdDurationThreshold: hotkey.holdDurationThreshold, monitor: self)

// СТАЛО:
HotkeyTapContext(keyCode: ..., modifiers: ..., monitor: self)
```

**В CGEventTap callback упростить логику до оригинальной:**
```swift
// Обрабатываем press/release (без hold detection)
if type == .keyDown && !ctx.isPressed {
    ctx.isPressed = true
    DispatchQueue.main.async {
        ctx.monitor?.isHotkeyPressed = true
        ctx.monitor?.eventContinuation?.yield(.pressed)
        ctx.monitor?.onHotkeyPress?()
        LogManager.keyboard.info("Горячая клавиша нажата: \(ctx.keyCode.displayName)")
    }
    return nil // Поглощаем событие
} else if type == .keyUp && ctx.isPressed {
    ctx.isPressed = false
    DispatchQueue.main.async {
        ctx.monitor?.isHotkeyPressed = false
        ctx.monitor?.eventContinuation?.yield(.released)
        ctx.monitor?.onHotkeyRelease?()
        LogManager.keyboard.info("Горячая клавиша отпущена: \(ctx.keyCode.displayName)")
    }
    return nil
}
return Unmanaged.passRetained(event)
```

---

### Step 4: Обновить HotkeySettingsView.swift

**Убрать "Hold Detection" SettingsCard** (всё содержимое от `// Hold Detection Settings` до закрывающей `}`)

**Обновить Hotkey Recorder card** — добавить объяснение ограничений:
```swift
SettingsCard(title: Strings.Hotkeys.hotkey, icon: "keyboard.badge.ellipsis", color: .purple) {
    VStack(alignment: .leading, spacing: 12) {
        // ... HotkeyRecorderView ...

        // Объяснение ограничений
        VStack(alignment: .leading, spacing: 4) {
            Text("Allowed keys:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("• F1-F19 without modifiers")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("• Any key with ⌘ / ⌥ / ⌃ modifier")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Plain letter/symbol keys are not allowed (conflict with text input)")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
}
```

**Обновить "Recommended Keys" card:**
```swift
SettingsCard(title: "Recommended Keys", icon: "star.fill", color: .yellow) {
    VStack(alignment: .leading, spacing: 8) {
        Text("F13-F19: Rarely used by other apps")
        Text("⌥+key: Option + any letter/number (e.g. ⌥` or ⌥F)")
        Text("⌃+key: Control + any key")
        Text("Avoid: F1-F12 (system media/brightness keys)")
        Text("Avoid: ⌘Q, ⌘W, ⌘Tab (system shortcuts)")
    }
    .font(.caption)
    .foregroundColor(.secondary)
}
```

---

### Step 5: Обновить HotkeyRecorderView (если нужно)

Проверить `HotkeyRecorderView` — если он принимает любую клавишу, добавить проверку через `hotkeyManager.isValidHotkey()` перед сохранением. Показывать inline ошибку если клавиша запрещена.

**Найти файл**: `Glob` по `HotkeyRecorderView.swift`

---

## Key Decisions Made in Previous Sessions

1. **CGEventTap вместо Carbon API**: Оставляем CGEventTap, т.к. Accessibility всё равно требуется для CGEvent.post() при вставке текста. Нет смысла держать два API.

2. **HotkeySource enum удалён**: Больше нет `.preset`/`.custom` разделения. Один universal тип клавиш.

3. **Миграция**: В `migrateOldStorageIfNeeded()` в HotkeyManager уже реализована миграция из старых ключей `pushToTalkPresetHotkey`/`pushToTalkCustomHotkey`.

4. **defaultHotkey**: `Hotkey(name: "F16", keyCode: 106, displayName: "F16", modifiers: [])` — F16 безопасен без модификаторов т.к. это F-key.

## Notes

- **НЕ добавлять** KeyboardShortcuts (sindresorhus) библиотеку — это отдельное решение если понадобится
- **НЕ возвращать** Carbon API — CGEventTap достаточен, Accessibility всё равно нужна
- **После реализации** — пересобрать через `./build_app.sh` и проверить
