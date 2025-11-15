---
name: m-implement-hybrid-hotkey-api
branch: feature/m-implement-hybrid-hotkey-api
status: pending
created: 2025-11-15
---

# Hybrid Hotkey API Implementation

## Problem/Goal
Currently, KeyboardMonitor uses only Carbon API for F13-F19 keys. We need to implement a hybrid approach with two modes:

**Preset Mode (Carbon API)**:
- List of predefined F13-F19 combinations
- Works reliably without Apple code signature
- No additional permissions needed (Accessibility already granted for clipboard)

**Custom Mode (CGEventTap)**:
- User can record any key combination
- Uses CGEventTap for global hotkey capture
- Leverages existing Accessibility permission

This provides flexibility: users can choose from reliable presets OR record custom combinations. No fallback needed - if custom hotkey doesn't work, user selects different one.

## Success Criteria
- [ ] HotkeySettingsView shows preset list of F13-F19 combinations (Carbon API mode)
- [ ] HotkeySettingsView has "Custom Hotkey" mode for any key combination (CGEventTap mode)
- [ ] KeyboardMonitor automatically switches between Carbon API and CGEventTap based on hotkey source
- [ ] Preset F-keys work reliably without Apple code signature using Carbon API
- [ ] Custom hotkeys use CGEventTap (Accessibility permission already granted for clipboard access)
- [ ] Switching between preset and custom modes preserves current selection
- [ ] All existing functionality preserved (AsyncStream, callbacks, event handling)
- [ ] Clear UI indication which mode is active (preset vs custom)

## Context Manifest

### How the Current Hotkey System Works: Carbon API for F13-F19 Only

The application currently uses **Carbon Event Manager API** exclusively for hotkey monitoring. This is a deliberate architectural choice because Carbon API offers F-key (F13-F19) registration WITHOUT requiring Accessibility permissions - only microphone permission is needed for the app's core functionality.

#### Entry Point and Initialization Flow

When the application starts, `AppCoordinator.start()` orchestrates the initialization sequence:

1. **Service Container Creation**: `ServiceContainer.shared` (singleton DI container) lazily initializes all services including `KeyboardMonitor` and `HotkeyManager`
2. **Hotkey Loading**: `HotkeyManager.init()` loads the saved hotkey from UserDefaults or defaults to F16 (keyCode: 106)
3. **Keyboard Monitoring Setup**: `AppCoordinator.setupKeyboardMonitoring()` calls `keyboardMonitor.startMonitoring()` on the main thread
4. **AsyncStream Event Processing**: Two parallel `Task` blocks consume AsyncStreams:
   - `keyboardMonitor.hotkeyEvents` → triggers `recordingCoordinator.startRecording()` / `stopRecording()`
   - `audioService.audioChunks` → triggers `recordingCoordinator.handleAudioChunk()`

#### Carbon API Registration: How F-Keys are Captured

The `KeyboardMonitor.startMonitoring()` method (`Sources/Services/Implementation/KeyboardMonitor.swift:62`) implements a sophisticated two-layer approach:

**Layer 1: Carbon Event Handler for Hotkey Events**
```swift
// Registers TWO event types: kEventHotKeyPressed and kEventHotKeyReleased
var eventTypes = [
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
]
InstallEventHandler(GetApplicationEventTarget(), handleCarbonEvent, 2, &eventTypes, nil, &eventHandler)
```

This installs a Carbon event handler that receives both press and release events for registered hotkeys. The handler is a static C-style callback (`handleCarbonEvent` at line 218).

**Layer 2: Carbon Hotkey Registration**
```swift
let hotkeyID = EventHotKeyID(signature: OSType(0x50545400), id: 1) // 'PTT\0' signature
let modifiers = carbonModifiers(from: hotkey.modifiers) // Converts CGEventFlags to Carbon modifiers
RegisterEventHotKey(
    UInt32(hotkey.keyCode),
    modifiers,
    hotkeyID,
    GetApplicationEventTarget(),
    OptionBits(kEventHotKeyExclusive),  // EXCLUSIVE capture - blocks system handlers
    &hotKeyRef
)
```

The `kEventHotKeyExclusive` flag is CRITICAL - it tells the system this application owns the hotkey exclusively, blocking system actions like the Emoji picker for F16.

**Layer 3: CGEventTap for Additional Blocking (Requires Accessibility)**

Even with exclusive Carbon registration, some system handlers can still fire. To fully block the key from reaching the system, `setupEventTap(for: keyCode)` (line 128) creates a CGEventTap:

```swift
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,  // Insert at the HEAD of the event chain
    options: .defaultTap,
    eventsOfInterest: keyDown | keyUp,
    callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let targetKeyCode = Int64(keyCodePtr.pointee)

        if eventKeyCode == targetKeyCode {
            return nil  // CONSUME the event - system never sees it
        }
        return Unmanaged.passRetained(event)
    },
    userInfo: keyCodePtr
)
```

This tap intercepts keyboard events BEFORE they reach other applications or system handlers. Returning `nil` completely consumes the event. The tap is added to the current run loop with `.commonModes` to ensure it works even when modal dialogs are open.

**IMPORTANT**: CGEventTap requires Accessibility permission. The code checks `AXIsProcessTrusted()` and logs a warning if not granted, but Carbon hotkey registration still works without it - you just might get system side effects (like Emoji picker for F16).

#### Event Processing: From Carbon Callback to AsyncStream

The Carbon event handler (`handleCarbonEvent` at line 218) is a C-style callback with signature:
```swift
(EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus
```

**Event Flow**:
1. Carbon calls `handleCarbonEvent` when the registered hotkey is pressed or released
2. Handler extracts `EventHotKeyID` from the event using `GetEventParameter`
3. Verifies the signature matches `0x50545400` ('PTT\0') and id == 1
4. Checks current `isHotkeyPressed` state to determine if this is a press or release event (Carbon events don't distinguish directly)
5. Updates `isHotkeyPressed` boolean flag
6. Yields event to AsyncStream: `eventContinuation?.yield(.pressed)` or `.released`
7. Also calls deprecated callback API for backwards compatibility: `onHotkeyPress?()` or `onHotkeyRelease?()`
8. Returns `noErr` to indicate event was handled (does NOT call `CallNextEventHandler` - this consumes the event)

The `eventContinuation` is an `AsyncStream<HotkeyEvent>.Continuation` stored when the `hotkeyEvents` AsyncStream is created (line 14-24). This enables modern async/await consumption in `AppCoordinator`.

#### Hotkey Persistence and Validation

`HotkeyManager` (`Sources/Managers/Implementation/HotkeyManager.swift`) manages hotkey configuration:

**Storage**: `UserDefaults` with key `"pushToTalkHotkey"`, encoded as JSON using `Codable`

**Hotkey Struct** (line 134):
```swift
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let name: String
    public let keyCode: CGKeyCode  // UInt16
    public let displayName: String
    public let modifiers: CGEventFlags  // Stored as rawValue (UInt64) in Codable
}
```

**Validation** (`isValidHotkey` at line 78):
- Rejects modifier-only keys (Cmd/Shift/Option/Control keycodes without a main key)
- Rejects dangerous system combos: Cmd+Q (quit), Cmd+W (close), Cmd+Tab (app switcher), Cmd+Space (Spotlight conflict)

**Change Notification**: When a new hotkey is saved, `HotkeyManager.saveHotkey()` posts `Notification.Name.hotkeyDidChange` with the new `Hotkey` object. `KeyboardMonitor` subscribes to this notification via Combine (line 52-58) and calls `restartMonitoring()` which stops and restarts monitoring with the new hotkey.

#### UI: Current HotkeySettingsView (F-Keys Only)

`HotkeySettingsView` (`Sources/Presentation/Views/Settings/HotkeySettingsView.swift`) currently shows:

1. **Picker** for F13-F19 selection (line 16-47):
   - Binding to `hotkeyManager.currentHotkey.keyCode`
   - Hardcoded map of keyCode → name (F13=105, F14=107, F15=113, F16=106, F17=64, F18=79, F19=80)
   - On change: creates new `Hotkey` struct with modifiers=[] and calls `hotkeyManager.saveHotkey()`

2. **Current hotkey display** (line 60-68):
   - Shows `hotkeyManager.currentHotkey.displayName` in large bold text

3. **Instructions card** (line 71-77):
   - Static usage instructions

**CRITICAL INSIGHT**: There's an existing `HotkeyRecorderView` in `Sources/UI/HotkeyRecorderView.swift` that's NOT currently used in the UI! This view already implements custom hotkey recording using NSEvent monitors (not CGEventTap for monitoring).

#### The Existing HotkeyRecorderView: Custom Hotkey Recording

`HotkeyRecorderView` (line 6 in `Sources/UI/HotkeyRecorderView.swift`) implements a full custom hotkey recorder:

**Recording Mechanism** (line 83-104):
- Uses `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged])` to capture keys within the app window
- Uses `NSEvent.addGlobalMonitorForEvents(matching: [.keyDown])` to block F-keys from triggering system actions during recording
- When recording starts, shows "Press any key..." prompt
- Escape cancels recording
- Modifier-only keys rejected with warning
- Validates against dangerous combos (Cmd+Q, Cmd+W, Cmd+Tab)
- Creates `Hotkey` struct with full modifier support
- Auto-stops recording 300ms after key capture

**Key Translation**:
- Uses `CGKeyCode.displayName` extension (in `HotkeyManager.swift` line 182-260) to get human-readable names
- Uses `CGEventFlags.displayName` extension (line 265-276) to format modifiers as symbols (⌃⌥⇧⌘)

**IMPORTANT**: This recorder uses NSEvent monitors for RECORDING custom keys, but does NOT implement the monitoring for TRIGGERING hotkeys during normal app operation. That's the missing piece.

### What Needs to Change: Hybrid Architecture Implementation

The task requires implementing a **mode-switching architecture** where the hotkey source determines which monitoring API is used:

#### New Data Model: Hotkey Source Enum

Add a `source` property to `Hotkey` struct:
```swift
public enum HotkeySource: String, Codable {
    case preset    // F13-F19 presets (Carbon API)
    case custom    // User-recorded (CGEventTap API)
}

public struct Hotkey {
    // ... existing properties ...
    public let source: HotkeySource  // NEW
}
```

#### KeyboardMonitor: API Mode Switching

`KeyboardMonitor.startMonitoring()` needs to branch based on `hotkey.source`:

**Preset Mode (F13-F19)**: Use CURRENT implementation
- Carbon `RegisterEventHotKey` + `InstallEventHandler`
- Optional CGEventTap for full blocking (if Accessibility granted)
- Carbon callback → AsyncStream

**Custom Mode (Any Key)**: Use ONLY CGEventTap
- Create CGEventTap that monitors keyDown/keyUp for the specific keyCode + modifiers
- CGEventTap callback → AsyncStream (yield .pressed / .released)
- REQUIRES Accessibility permission (check `AXIsProcessTrusted()` first)
- Carbon API NOT used for custom keys

**CGEventTap for Custom Hotkeys** - Implementation Pattern:

The current `setupEventTap()` (line 128) provides the pattern, but it only BLOCKS keys. For custom hotkeys, the tap needs to:
1. Monitor ALL keyboard events (not just blocking one key)
2. Compare event keyCode + modifiers against the configured hotkey
3. Track press/release state
4. Yield to AsyncStream when hotkey is pressed/released
5. Return `nil` for matching events (consume them), `Unmanaged.passRetained(event)` for others

**Critical Pattern for Press/Release Detection**:
```swift
callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
    let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let eventModifiers = event.flags

    // Compare against target hotkey (passed via refcon)
    guard let hotkeyData = refcon?.assumingMemoryBound(to: HotkeyData.self) else {
        return Unmanaged.passRetained(event)
    }

    if eventKeyCode == hotkeyData.keyCode && eventModifiers.contains(hotkeyData.modifiers) {
        if type == .keyDown {
            // Yield .pressed to AsyncStream (need to store continuation in refcon)
        } else if type == .keyUp {
            // Yield .released
        }
        return nil  // Consume the event
    }

    return Unmanaged.passRetained(event)
}
```

**Challenge**: AsyncStream continuation can't be passed via `refcon` (C pointer). Solution: Use a reference type (class) to hold both hotkey data AND continuation reference:
```swift
class HotkeyTapContext {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
    weak var continuation: AsyncStream<HotkeyEvent>.Continuation?
}
```

#### HotkeySettingsView: Preset vs Custom Mode Picker

Replace the current single picker with a segmented mode selector:

**UI Structure**:
1. **Mode Picker**: Segmented control "Preset F-Keys" vs "Custom Hotkey"
2. **Conditional View**:
   - If preset mode: Show current F13-F19 picker
   - If custom mode: Show `HotkeyRecorderView` (already exists!)
3. **Permission Warning**: If custom mode selected but Accessibility not granted, show alert with instructions

**State Management**:
- Add `@State private var selectedMode: HotkeySource = .preset`
- Sync with `hotkeyManager.currentHotkey.source`
- On mode switch, preserve last hotkey for that mode (two separate UserDefaults keys)

#### Hotkey Persistence: Two Separate Storage Keys

`HotkeyManager` needs to maintain TWO hotkeys:
- `"pushToTalkPresetHotkey"` → Last selected preset (F13-F19)
- `"pushToTalkCustomHotkey"` → Last recorded custom hotkey

When mode switches, load the appropriate saved hotkey. This prevents losing custom hotkey when switching to preset mode and vice versa.

#### Permission Handling: Accessibility Required for Custom Mode

`PermissionManager` already checks Accessibility via `AXIsProcessTrusted()` and has `requestAccessibilityPermission()` to open System Settings. The app ALREADY requests Accessibility for clipboard insertion (TextInserter uses it), so this permission is likely already granted in most cases.

**Flow**:
1. User selects "Custom Hotkey" mode
2. Check `PermissionManager.checkAccessibilityPermission()`
3. If not granted: Show alert with `PermissionManager.showPermissionInstructions(for: .accessibility)` and disable custom mode
4. If granted: Enable HotkeyRecorderView

#### Existing Event Tap Knowledge

The codebase ALREADY uses CGEventTap in two places:
1. **KeyboardMonitor.setupEventTap()** (line 128) - Blocks F-keys from system (complementary to Carbon)
2. **TextInserter.simulatePaste()** (line 62 in TextInserter.swift) - Uses `CGEvent(keyboardEventSource:)` to simulate Cmd+V

The existing `setupEventTap()` shows the complete pattern:
- `CGEvent.tapCreate()` with callback
- `CFMachPortCreateRunLoopSource()` to create run loop source
- `CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)` to attach to run loop
- `CGEvent.tapEnable(tap: tap, enable: true)` to activate
- Cleanup: `CGEvent.tapEnable(tap, false)` + `CFMachPortInvalidate(tap)`

#### AppConstants: Preset Keys Definition

`AppConstants.availableFunctionKeys` already defines the F13-F19 list as strings. For the preset picker, use the keyCode mapping that already exists in `HotkeySettingsView` (line 19-27) and `CGKeyCode.displayName` extension.

#### Strings Localization

`Strings.Hotkeys` enum exists (line 82 in Strings.swift) with keys like `hotkeySelection`, `recordNewHotkey`, etc. Add new keys:
- `presetMode` - "Preset F-Keys"
- `customMode` - "Custom Hotkey"
- `modeSelection` - "Hotkey Mode"
- `accessibilityRequired` - "Accessibility permission required for custom hotkeys"

### Technical Reference Details

#### Component Interfaces & Signatures

**KeyboardMonitorProtocol** (no changes needed):
```swift
protocol KeyboardMonitorProtocol: ObservableObject {
    var isHotkeyPressed: Bool { get }
    var hotkeyEvents: AsyncStream<HotkeyEvent> { get }
    func startMonitoring() -> Bool
    func stopMonitoring()
}
```

**HotkeyManagerProtocol** (needs update):
```swift
protocol HotkeyManagerProtocol: ObservableObject {
    var currentHotkey: Hotkey { get set }
    var isRecording: Bool { get set }  // For HotkeyRecorderView integration
    var currentKeyCode: CGKeyCode { get }

    func saveHotkey(_ hotkey: Hotkey)
    func isValidHotkey(_ hotkey: Hotkey) -> Bool

    // NEW: Mode-aware saving
    func savePresetHotkey(_ hotkey: Hotkey)
    func saveCustomHotkey(_ hotkey: Hotkey)
    func loadHotkey(for source: HotkeySource) -> Hotkey?
}
```

**HotkeyEvent Enum** (existing, no changes):
```swift
public enum HotkeyEvent: Sendable {
    case pressed
    case released
}
```

**Hotkey Struct** (needs update):
```swift
public struct Hotkey: Identifiable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let keyCode: CGKeyCode
    public let displayName: String
    public let modifiers: CGEventFlags
    public let source: HotkeySource  // NEW

    // Existing Codable implementation encodes modifiers as rawValue (UInt64)
}
```

**HotkeySource Enum** (new):
```swift
public enum HotkeySource: String, Codable {
    case preset
    case custom
}
```

#### Data Structures

**UserDefaults Keys** (new):
```swift
// In AppConstants.UserDefaultsKeys
public static let presetHotkey = "pushToTalkPresetHotkey"
public static let customHotkey = "pushToTalkCustomHotkey"
public static let hotkeyMode = "pushToTalkHotkeyMode"  // Stores current HotkeySource
```

**F-Key KeyCode Mapping** (existing):
```swift
let fKeyMap: [UInt16: String] = [
    105: "F13",
    107: "F14",
    113: "F15",
    106: "F16",  // Default
    64: "F17",
    79: "F18",
    80: "F19"
]
```

**CGEventTap Callback Context** (new class needed):
```swift
class HotkeyTapContext {
    let keyCode: CGKeyCode
    let modifiers: CGEventFlags
    var continuation: AsyncStream<HotkeyEvent>.Continuation?
    var isPressed: Bool = false  // Track state for press/release

    init(keyCode: CGKeyCode, modifiers: CGEventFlags, continuation: AsyncStream<HotkeyEvent>.Continuation?) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.continuation = continuation
    }
}
```

#### Configuration Requirements

**Entitlements** (already exists in `Entitlements.plist`):
- App Sandbox: NO (required for CGEventTap)
- Hardened Runtime: YES
- Code signing: Developer ID Application (for distribution) or Development (for testing)

**Info.plist** (check these exist):
- `NSMicrophoneUsageDescription` - Required for microphone
- No specific key for Accessibility (handled by system prompt)

#### File Locations

**Implementation files to modify**:
- `Sources/Managers/Implementation/HotkeyManager.swift` - Add source property, dual storage
- `Sources/Services/Implementation/KeyboardMonitor.swift` - Add CGEventTap monitoring mode
- `Sources/Presentation/Views/Settings/HotkeySettingsView.swift` - Add mode picker and conditional view

**New files to create**:
- None (HotkeyRecorderView already exists)

**Files that use Hotkey** (grep results show):
- `Sources/Services/Protocols/KeyboardMonitorProtocol.swift` - Event enum only
- `Sources/Managers/Implementation/HotkeyManager.swift` - Hotkey struct definition
- `Sources/UI/HotkeyRecorderView.swift` - Creates Hotkey instances
- `Sources/Presentation/Views/Settings/HotkeySettingsView.swift` - Displays hotkey

**Notification dependencies**:
- `Notification.Name.hotkeyDidChange` posted by HotkeyManager, observed by KeyboardMonitor

#### Key Code Reference (from CGKeyCode extension)

Function keys:
- F13 = 105, F14 = 107, F15 = 113, F16 = 106, F17 = 64, F18 = 79, F19 = 80

Modifier detection in CGEventFlags:
- `.maskCommand` (⌘), `.maskShift` (⇧), `.maskAlternate` (⌥), `.maskControl` (⌃)

#### Permission Check Pattern

```swift
// Check Accessibility (required for CGEventTap custom hotkeys)
let trusted = AXIsProcessTrusted()
if !trusted {
    // Show instructions
    permissionManager.requestAccessibilityPermission()  // Opens System Settings
    return false
}
```

#### AsyncStream Pattern (existing implementation to follow)

```swift
public var hotkeyEvents: AsyncStream<HotkeyEvent> {
    AsyncStream { continuation in
        self.eventContinuation = continuation
        continuation.onTermination = { @Sendable [weak self] _ in
            self?.eventContinuation = nil
        }
    }
}
```

The continuation is stored as `private var eventContinuation: AsyncStream<HotkeyEvent>.Continuation?` and used in callbacks: `eventContinuation?.yield(.pressed)`.

### Migration Notes

**Backwards Compatibility**:
- Existing saved hotkeys (without `source` property) should default to `.preset` mode
- `Codable` decoding should use `try container.decodeIfPresent(HotkeySource.self, forKey: .source) ?? .preset`

**Testing Considerations**:
- Preset mode should work identically to current implementation
- Custom mode requires Accessibility permission - test behavior when denied
- Mode switching should preserve separate hotkeys
- Notification `hotkeyDidChange` should trigger monitoring restart with correct API

**UI/UX Flow**:
1. User opens settings → sees current hotkey (preset or custom based on last saved mode)
2. User switches mode → loads last hotkey for that mode OR defaults (F16 for preset, nil for custom)
3. User selects preset → picker immediately saves and restarts monitoring (Carbon API)
4. User selects custom → shows HotkeyRecorderView → records key → saves and restarts monitoring (CGEventTap API)
5. AppCoordinator AsyncStream consumption remains UNCHANGED (same HotkeyEvent enum)

## User Notes
<!-- Any specific notes or requirements from the developer -->

## Work Log
<!-- Updated as work progresses -->
- [YYYY-MM-DD] Started task, initial research
