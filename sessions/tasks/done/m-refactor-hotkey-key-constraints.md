---
name: m-refactor-hotkey-key-constraints
branch: feature/m-refactor-hotkey-key-constraints
status: complete
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

- [x] Убрана hold detection логика (откат)
- [x] `isValidHotkey()` запрещает regular keys без модификаторов
- [x] F1-F19 разрешены без модификаторов
- [x] HotkeyRecorderView не принимает regular key без модификатора (показывает ошибку/игнорирует)
- [x] UI объясняет ограничение пользователю
- [x] Компиляция без ошибок

## Work Log

### 2026-02-18

#### Completed

**Step 1 -- Hold Detection removal (HotkeyManager.swift):**
- Removed `holdDurationThreshold`, `requiresHold`, related CodingKeys/encode/decode/equality from `Hotkey` struct

**Step 2 -- Key constraint validation (HotkeyManager.swift):**
- Added `public static let functionKeyCodes` (F1-F19 key codes)
- Added `public static let modifierOnlyKeys` and `public static let dangerousKeyCodes`
- Rewrote `isValidHotkey()`: F-keys allowed without modifiers; regular keys require Command/Option/Control; dangerous combos blocked

**Step 3 -- Hold Detection removal (KeyboardMonitor.swift):**
- Removed `holdTimer`, `keyDownTime`, `isHoldActivated` from `HotkeyTapContext`
- Simplified CGEventTap callback to direct press/release without hold detection logic

**Step 4 -- UI updates (HotkeySettingsView.swift):**
- Removed "Hold Detection" SettingsCard (Toggle + Slider)
- Added "Allowed keys" info block and "Recommended Keys" card
- Added "How to Use" instructions card
- Localized all hardcoded strings to `Strings.Hotkeys.*`

**Step 5 -- Recorder validation (HotkeyRecorderView.swift):**
- Added inline validation: rejects regular keys without modifiers, shows warning messages
- Rejects dangerous system combinations (Cmd+Q, Cmd+W, Cmd+Tab)
- Deduplicated constants to use `HotkeyManager.functionKeyCodes`, `.modifierOnlyKeys`, `.dangerousKeyCodes`
- Localized all hardcoded strings to `Strings.Hotkeys.*`

**Code review fixes:**
- Fixed TogglePlayPause race condition in `MediaRemoteManager.resume()` -- added `isPlaying()` guard before toggle to prevent pausing an already-playing player
- Added ~25 new localization keys to `Strings.swift`, `en.lproj/Localizable.strings`, `ru.lproj/Localizable.strings`
- Build verified clean (`swift build` succeeds)

#### Decisions
- Key code constants centralized as `public static` on `HotkeyManager` rather than duplicated in `HotkeyRecorderView`
- `MediaRemoteManager.resume()` uses async `isPlaying()` callback before toggle to handle race between user manual resume and app-triggered resume

#### Files Modified
- `Sources/Managers/Implementation/HotkeyManager.swift`
- `Sources/Services/Implementation/KeyboardMonitor.swift`
- `Sources/Presentation/Views/Settings/HotkeySettingsView.swift`
- `Sources/UI/HotkeyRecorderView.swift`
- `Sources/Utils/Media/MediaRemoteManager.swift`
- `Sources/Utils/Constants/Strings.swift`
- `Resources/Localization/en.lproj/Localizable.strings`
- `Resources/Localization/ru.lproj/Localizable.strings`

## Key Decisions

1. **CGEventTap only** -- Carbon API removed in prior refactor; CGEventTap sufficient since Accessibility required anyway for `CGEvent.post()` text insertion
2. **No HotkeySource enum** -- single universal `Hotkey` type, migration from old preset/custom keys already in place
3. **Default hotkey**: `F16` (keyCode 106) -- safe F-key, no modifier needed
4. **No KeyboardShortcuts library** -- keeping native CGEventTap approach
