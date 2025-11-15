---
name: m-implement-modern-recording-window
branch: feature/m-implement-modern-recording-window
status: pending
created: 2025-11-15
---

# Modern Recording Window with Liquid Glass Effect

## Problem/Goal
Current FloatingRecordingWindow has a basic design. We need to redesign it using modern macOS design patterns (November 2025), specifically the Liquid Glass effect that's trending in macOS interfaces.

The new window should display:
- **Recording status** with visual feedback (recording/processing states)
- **Current active model** name
- **Stop words** list to remind user which words cancel recording
- Modern Liquid Glass translucent background effect
- Smooth animations and transitions

This provides better user feedback during recording and makes the app feel more polished and native to modern macOS.

## Success Criteria
- [ ] FloatingRecordingWindow uses Liquid Glass / translucent material effect
- [ ] Window displays current Whisper model name from ModelManager
- [ ] Window displays active stop words from UserSettings
- [ ] Recording state shows clear visual indicators (recording/processing/error)
- [ ] Smooth animations for state transitions (fade in/out, color changes)
- [ ] Window follows modern macOS design guidelines (November 2025)
- [ ] Maintains existing functionality (appears during recording, dismisses after)
- [ ] Responsive layout that adapts to content length

## Context Manifest

### How FloatingRecordingWindow Currently Works

The FloatingRecordingWindow is a critical UI component that provides visual feedback during voice recording and transcription. It's a borderless NSWindow that floats above all other windows and appears when the user presses the hotkey to start recording.

**Window Lifecycle and Architecture:**

When the application starts, AppCoordinator creates a FloatingRecordingWindow instance (line 45 in `Sources/App/AppCoordinator.swift`) and passes it to RecordingCoordinator. The window is initialized with:
- Center-screen positioning (400x200 default size)
- Borderless style mask for custom appearance
- `.floating` window level to stay on top
- Clear/transparent background with shadow
- `isMovableByWindowBackground = true` for drag support
- `collectionBehavior = [.canJoinAllSpaces, .stationary]` for multi-space support
- Initially hidden via `orderOut(nil)`

**Recording Flow - State Machine:**

The window operates through a RecordingViewModel with a state machine (`RecordingState` enum):

1. **Recording Start (`showRecording(maxDuration:)`):**
   - RecordingCoordinator calls `floatingWindow.showRecording()` when user presses hotkey (line 258 in RecordingCoordinator)
   - ViewModel updates to `.recordingWithText(partialText: "")` state
   - Fetches current audio device name from AudioDeviceManager.shared.selectedDevice
   - Starts countdown timer (default 60s max duration from UserSettings.maxRecordingDuration)
   - Shows window with fade-in animation (0.3s, alpha 0→1.0)
   - Displays microphone icon, device name, countdown timer, and placeholder text

2. **Real-time Transcription Updates (`updatePartialTranscription(_:)`):**
   - RecordingCoordinator calls this when WhisperService transcribes audio chunks (line 226)
   - Updates state to `.recordingWithText(partialText: transcribedText)`
   - Text replaces completely (not appended) because WhisperService re-transcribes cumulative audio
   - Scrollable text area shows transcribed speech in real-time

3. **Processing Transition (`showProcessing()`):**
   - Called when user releases hotkey and transcription begins (line 273)
   - Triggers `animateToCompactMode()` which:
     - Changes state to `.processingCompact`
     - Animates window size from 400x200 to 60x60 circular shape
     - Moves to upper center of screen (10% below center vertically)
     - Uses NSAnimationContext with 0.4s easeInEaseOut timing
     - SwiftUI automatically animates corner radius change (20→30 for circular)
     - Shows blue pulsing waveform icon

4. **Completion/Error (`hide()`):**
   - Called when transcription completes or errors occur (line 280, 442)
   - Stops countdown timer
   - Fade-out animation (0.3s, alpha 1.0→0)
   - `orderOut(nil)` to hide window

**ViewModel State Management:**

RecordingViewModel (`Sources/UI/FloatingRecordingWindow.swift:192`) manages:
- `@Published var state: RecordingState` - drives UI changes
- `@Published var pulseAnimation: Bool` - triggers pulsing animations
- `@Published var audioDeviceName: String` - from AudioDeviceManager
- `@Published var remainingTime: TimeInterval` - countdown from maxDuration
- Timer with 0.1s interval updates remainingTime every 100ms
- Timer turns red when <10 seconds remaining

**Current Visual Design (Liquid Glass v1):**

The existing implementation already uses a Liquid Glass effect (`Sources/UI/FloatingRecordingWindow.swift:282-321`):
- NSVisualEffectView with `.hudWindow` material
- LinearGradient overlay with white opacity layers (0.25→0.12→0.18→0.08)
- Dynamic state-based glow (red for recording, blue for processing)
- Gradient stroke border (white opacity 0.6→0.25→0.5)
- Multiple shadows for depth (state color + black)
- Spring animation on state changes (response: 0.4, dampingFraction: 0.75)

**Integration Points:**

- **ModelManager:** Currently does NOT display model name in window. Need to fetch from `ServiceContainer.shared.modelManager.currentModel` (String property, e.g., "small", "base", "large-v3")
- **UserSettings:** Stop words available via `ServiceContainer.shared.userSettings.stopWords` (array of strings, default ["отмена"])
- **Animations:** Existing patterns use `.spring()`, `.easeInOut()`, `.repeatForever()` with durations from UIConstants (0.2-0.5s)

### What Needs to Change for Modern Design

**Task Requirements:**

1. **Display Model Name:**
   - Add text showing current Whisper model from ModelManager.currentModel
   - Use displayName mapping: "small" → "Small", "large-v3" → "Large V3" (from ModelManager.supportedModels array)
   - Position: likely in header area alongside device name
   - Update when model changes (observe ModelManager @Published property or AppConstants.Notifications.modelChanged)

2. **Display Stop Words:**
   - Show UserSettings.stopWords array (default: ["отмена"])
   - Design consideration: Could be comma-separated list or pill-style badges
   - Helps user remember which words cancel recording
   - Update reactively when settings change

3. **Modernize Liquid Glass Effect (November 2025):**
   - Current design uses `.hudWindow` material
   - Modern alternatives on macOS 14+:
     - `.sidebar` - subtle translucency
     - `.headerView` - header-style blur
     - `.menu` - menu-style translucency
     - `.popover` - popover background
     - `.underWindowBackground` - ultra-thin material
   - Consider layered glass effect with multiple blur levels
   - Enhance gradients with more sophisticated color stops
   - Add depth with multi-layer shadows

4. **Enhanced Animations:**
   - Current: Spring animations on state changes
   - Consider: Smooth transitions for text updates, icon morphing, color shifts
   - Use SwiftUI `.matchedGeometryEffect` for seamless transformations
   - Timing: UIConstants provides shortAnimationDuration (0.2s), mediumAnimationDuration (0.3s), longAnimationDuration (0.5s)

5. **Responsive Layout:**
   - Current: Fixed 400x200 → 60x60
   - Need: Adapt to content length (model name, stop words list, transcription text)
   - ScrollView already handles overflow for transcription text
   - Consider dynamic height based on stop words count

**Architecture Constraints:**

- Window is NSWindow subclass, content is SwiftUI via NSHostingController
- Cannot modify RecordingCoordinator or AppCoordinator (only update FloatingRecordingWindow)
- Must maintain existing public API: `showRecording()`, `updatePartialTranscription()`, `showProcessing()`, `hide()`, `showError()`, `resetTimer()`
- ViewModel is internal, can be enhanced freely
- State machine must preserve existing states or add new ones carefully

### Technical Reference

#### Available NSVisualEffectView Materials (macOS 14+)

```swift
// From VisualEffectBlur.swift - wrapper already exists
NSVisualEffectView.Material options:
- .sidebar            // Sidebar translucency
- .headerView         // Header-style blur
- .menu               // Menu-style background
- .popover            // Popover background
- .hudWindow          // HUD-style (current)
- .underWindowBackground // Ultra-thin
- .windowBackground   // Standard window
```

#### Existing Component Locations

**Files to Modify:**
- `/Users/nb/Developement/PushToTalk/Sources/UI/FloatingRecordingWindow.swift` (530 lines)
  - `FloatingRecordingWindow` class (lines 6-188) - NSWindow wrapper
  - `RecordingViewModel` class (lines 192-252) - Observable state
  - `RecordingState` enum (lines 256-263) - State machine
  - `RecordingStatusView` SwiftUI view (lines 265-509) - Main UI

**Helper Components:**
- `/Users/nb/Developement/PushToTalk/Sources/Presentation/Views/Shared/VisualEffectBlur.swift` - NSVisualEffectView wrapper
  - Supports `material` and `blendingMode` parameters
  - Already used in FloatingRecordingWindow

**Constants to Use:**
- `UIConstants.cardCornerRadius` (12) - for internal cards
- `UIConstants.smallCornerRadius` (6) - for pills/badges
- `UIConstants.cardPadding` (16) - internal padding
- `UIConstants.itemSpacing` (12) - spacing between elements
- `UIConstants.StateColors.recording` (Color.red) - recording state
- `UIConstants.StateColors.processing` (Color.orange) - processing state

**Accessing Dependencies:**

```swift
// In FloatingRecordingWindow.init() or showRecording():
let container = ServiceContainer.shared

// Get current model name
let modelName = container.modelManager.currentModel // String: "small", "base", etc.

// Get display name from ModelManager
if let modelInfo = (container.modelManager as? ModelManager)?.getModelInfo(modelName) {
    let displayName = modelInfo.displayName // "Small", "Base", etc.
}

// Get stop words
let stopWords = container.userSettings.stopWords // [String], e.g., ["отмена"]

// Get audio device (already done)
let deviceName = AudioDeviceManager.shared.selectedDevice?.name ?? "Default Microphone"
```

#### Animation Patterns in Codebase

**Spring animations (preferred for layout changes):**
```swift
.animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.state)
```

**Ease animations (for simple fades/scales):**
```swift
.animation(.easeInOut(duration: 0.2), value: partialText)
```

**Repeat forever (for pulsing indicators):**
```swift
.animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
```

**NSWindow animations:**
```swift
NSAnimationContext.runAnimationGroup({ context in
    context.duration = 0.4
    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    self.animator().setFrame(newFrame, display: true)
})
```

#### Localization Pattern (if adding new strings)

```swift
// Add to Strings.swift:
public enum Recording {
    public static let currentModel = NSLocalizedString("recording.currentModel", bundle: bundle, comment: "Current model label")
    public static let stopWords = NSLocalizedString("recording.stopWords", bundle: bundle, comment: "Stop words label")
}

// Usage:
Text(Strings.Recording.currentModel)
```

#### State Machine Flow

```
User presses hotkey
    ↓
RecordingCoordinator.startRecording()
    ↓
floatingWindow.showRecording(maxDuration: 60.0)
    ↓
State: .recordingWithText(partialText: "")
    ↓
[Real-time chunks arrive]
    ↓
floatingWindow.updatePartialTranscription("partial text...")
    ↓
State: .recordingWithText(partialText: "partial text...")
    ↓
User releases hotkey
    ↓
RecordingCoordinator.stopRecording()
    ↓
floatingWindow.showProcessing()
    ↓
State: .processingCompact (60x60 circular, blue pulsing)
    ↓
Transcription completes
    ↓
floatingWindow.hide()
    ↓
Window hidden (fade-out)
```

#### Design Considerations

**Model Name Display:**
- Should be prominent but not dominate the UI
- Could be SF Symbol "cpu" icon + text
- Update requires observing ModelManager changes or responding to Notifications.modelChanged

**Stop Words Display:**
- Array can be empty or contain multiple words
- Current defaults: ["отмена"] (Russian for "cancel")
- Visual options:
  - Pill-style badges with rounded corners
  - Comma-separated list with label
  - Collapsible section if list is long
- Color: Could use warning color (yellow/orange) to indicate "these words stop recording"

**Layout Adaptation:**
- Fixed width (400) is reasonable for readability
- Height could expand if stop words list is long
- Compact mode (60x60) should remain unchanged

**Performance:**
- Window updates on main thread (already enforced via DispatchQueue.main.async)
- @Published properties trigger SwiftUI updates efficiently
- Timer runs every 0.1s for smooth countdown

**Accessibility:**
- Consider VoiceOver labels for dynamic content
- High contrast support for text over glass background
- Dynamic Type for text scaling

## User Notes
<!-- Any specific notes or requirements from the developer -->

## Work Log
<!-- Updated as work progresses -->
- [YYYY-MM-DD] Started task, initial research
