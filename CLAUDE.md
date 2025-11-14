
@sessions/CLAUDE.sessions.md

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PushToTalk** is a lightweight voice-to-text application optimized for Apple Silicon (M1/M2/M3). It uses customizable hotkeys (default: F16) as a push-to-talk trigger and automatically inserts recognized speech at the current cursor position.

The application is built with **Swift** and uses **WhisperKit** for on-device speech recognition with Metal GPU acceleration.

## Architecture

**PushToTalk** follows **Clean Architecture** principles with clear separation of concerns and protocol-oriented design.

### Architectural Layers

```
┌─────────────────────────────────────────┐
│      Presentation Layer                 │
│  (Views, ViewModels, MenuBar)           │
├─────────────────────────────────────────┤
│      Coordination Layer                 │
│  (AppCoordinator, RecordingCoordinator, │
│   SettingsCoordinator)                  │
├─────────────────────────────────────────┤
│      Service Layer                      │
│  (WhisperService, AudioCaptureService,  │
│   KeyboardMonitor, TextInserter)        │
├─────────────────────────────────────────┤
│      Manager Layer                      │
│  (ModelManager, AudioDeviceManager,     │
│   VocabularyManager, HotkeyManager)     │
├─────────────────────────────────────────┤
│      Infrastructure                     │
│  (DI Container, Constants, Extensions)  │
└─────────────────────────────────────────┘
```

### Dependency Injection

**ServiceContainer** (`Sources/App/ServiceContainer.swift`)
- Single source of truth for all dependencies
- Lazy initialization of services and managers
- Protocol-based dependencies for testability
- **Usage**:
  ```swift
  let container = ServiceContainer.shared
  let whisperService = container.whisperService  // WhisperServiceProtocol
  let audioService = container.audioService      // AudioCaptureServiceProtocol
  ```

### Coordinators

#### 1. AppCoordinator (`Sources/App/AppCoordinator.swift`)
- **Responsibility**: Main application lifecycle and coordination
- **Features**:
  - Initializes menu bar with callbacks
  - Sets up keyboard monitoring via AsyncStream
  - Manages RecordingCoordinator and SettingsCoordinator
  - Handles permissions and model loading
- **Key Methods**:
  - `start()` - Application startup
  - `stop()` - Cleanup on termination

#### 2. RecordingCoordinator (`Sources/Coordinators/RecordingCoordinator.swift`)
- **Responsibility**: Recording and transcription workflow
- **Features**:
  - Manages audio recording lifecycle
  - Coordinates audio environment (ducking, volume boost)
  - Real-time transcription with chunk processing
  - Silence detection and stop-word handling
  - Sound feedback (start, stop, success, error)
- **Key Methods**:
  - `startRecording()` - Begins recording session
  - `stopRecording()` - Ends recording and performs transcription
  - `handleAudioChunk()` - Real-time chunk processing
  - `performTranscription()` - Main transcription workflow

#### 3. SettingsCoordinator (`Sources/Coordinators/SettingsCoordinator.swift`)
- **Responsibility**: Settings window management
- **Features**:
  - Creates and manages settings window lifecycle
  - Handles model changes via callback
  - Integrates with ModernSettingsView
- **Key Methods**:
  - `showSettings()` - Opens settings window
  - `windowWillClose()` - Cleanup on window close

### Core Services

All services implement **protocols** for testability and dependency injection.

#### 1. KeyboardMonitor (`Sources/Services/Implementation/KeyboardMonitor.swift`)
- **Protocol**: `KeyboardMonitorProtocol`
- **Technology**: Carbon Event Manager API (`RegisterEventHotKey`)
- **Advantage**: Does NOT require Accessibility permissions for function keys (F13-F19)
- **Modern API**: AsyncStream for hotkey events
- **Features**:
  - Supports F13-F19 and modifier keys (Right Cmd/Option/Control)
  - Automatic hotkey re-registration when user changes preference
  - Global event monitoring without Input Monitoring permissions
- **Key Methods**:
  - `startMonitoring()` - Registers global hotkey with Carbon Event Manager
  - `handleCarbonEvent()` - Processes kEventHotKeyPressed/Released events
  - `hotkeyEvents: AsyncStream<HotkeyEvent>` - Modern async event stream

#### 2. AudioCaptureService (`Sources/Services/Implementation/AudioCaptureService.swift`)
- **Protocol**: `AudioCaptureServiceProtocol`
- **Modern API**: AsyncStream for audio chunks
- **Features**:
  - Audio capture using AVAudioEngine
  - Real-time format conversion: native microphone format → 16kHz mono Float32
  - Buffer management with thread-safe locking
  - Chunk-based streaming via AsyncStream
- **Key Methods**:
  - `startRecording()` - Starts AVAudioEngine with format conversion pipeline
  - `stopRecording()` - Returns captured audio samples
  - `audioChunks: AsyncStream<[Float]>` - Real-time audio chunk stream

#### 3. WhisperService (`Sources/Services/Implementation/WhisperService.swift`)
- **Protocol**: `WhisperServiceProtocol`
- **Features**:
  - WhisperKit integration for on-device transcription
  - Metal GPU acceleration through MLX backend
  - Performance metrics (Real-Time Factor, transcription speed)
  - Chunk-based transcription for real-time feedback
- **Key Methods**:
  - `loadModel()` - Downloads and initializes WhisperKit model
  - `transcribe(audioSamples:contextPrompt:)` - Transcribes audio to text
  - `transcribeChunk()` - Real-time chunk transcription
  - `verifyMetalAcceleration()` - Checks Metal GPU availability

#### 4. TextInserter (`Sources/Services/Implementation/TextInserter.swift`)
- **Protocol**: `TextInserterProtocol`
- **Features**:
  - Inserts transcribed text at cursor position
  - Uses CGEvent API for keyboard simulation
- **Key Methods**:
  - `insertTextAtCursor(_ text: String)` - Simulates typing at cursor

### Managers

All managers implement **protocols** for dependency injection.

#### 1. ModelManager (`Sources/Managers/Implementation/ModelManager.swift`)
- **Protocol**: `ModelManagerProtocol`
- **Responsibility**: Whisper model management
- **Features**:
  - Download, delete, and scan models
  - Track download progress
  - Persist current model selection
- **Key Methods**:
  - `downloadModel() async throws` - Download model from Hugging Face
  - `deleteModel() async throws` - Remove downloaded model
  - `scanDownloadedModels()` - Refresh available models list

#### 2. AudioDeviceManager (`Sources/Managers/Implementation/AudioDeviceManager.swift`)
- **Protocol**: `AudioDeviceManagerProtocol`
- **Responsibility**: Audio input device management
- **Features**:
  - Scan available input devices
  - Persist device selection
  - Fallback to default device
- **Key Methods**:
  - `scanAvailableDevices()` - Refresh device list
  - `selectDevice(_ device: AudioDevice)` - Set active input device

#### 3. VocabularyManager (`Sources/Managers/Implementation/VocabularyManager.swift`)
- **Protocol**: `VocabularyManagerProtocol`
- **Responsibility**: Custom vocabulary and corrections
- **Features**:
  - Text corrections (literal and regex)
  - Import/export corrections dictionary
  - Default corrections for common terms
- **Key Methods**:
  - `addCorrection(from:to:)` - Add literal correction
  - `addRegexCorrection(pattern:replacement:)` - Add regex-based correction
  - `correctTranscription(_ text: String)` - Apply all corrections

#### 4. HotkeyManager (`Sources/Managers/Implementation/HotkeyManager.swift`)
- **Protocol**: `HotkeyManagerProtocol`
- **Responsibility**: Hotkey configuration
- **Features**:
  - Persists user hotkey preference to UserDefaults
  - Validates hotkey combinations
  - Supported keys: F13-F19, Right Command/Option/Control
- **Key Methods**:
  - `saveHotkey(_ hotkey: Hotkey)` - Persist hotkey choice
  - `isValidHotkey(_ hotkey: Hotkey)` - Validate hotkey combination

### ViewModels

#### 1. StatusBarViewModel (`Sources/Presentation/ViewModels/StatusBarViewModel.swift`)
- **Responsibility**: Menu bar state management
- **Features**:
  - Track app state (ready, recording, processing, error)
  - Update progress and status messages
  - Sync with model and service state
- **Published Properties**:
  - `currentState: AppState` - Current app state
  - `progress: Double` - Recording/processing progress
  - `modelSize: String` - Active model name
  - `statusMessage: String` - Human-readable status

#### 2. SettingsViewModel (`Sources/Presentation/ViewModels/SettingsViewModel.swift`)
- **Responsibility**: Settings UI state
- **Features**:
  - Model download and deletion
  - Track download progress
  - Error handling
- **Published Properties**:
  - `selectedModelSize: String` - User-selected model
  - `isDownloading: Bool` - Download in progress
  - `downloadProgress: Double` - Download percentage

#### 3. HistoryViewModel (`Sources/Presentation/ViewModels/HistoryViewModel.swift`)
- **Responsibility**: Transcription history management
- **Features**:
  - Filter and search entries
  - Copy, delete, and bulk operations
  - Selection management
- **Published Properties**:
  - `entries: [TranscriptionEntry]` - All history entries
  - `filteredEntries: [TranscriptionEntry]` - Filtered by search
  - `searchQuery: String` - User search text

### Project Structure

```
Sources/
├── App/
│   ├── AppDelegate.swift              (~48 lines - lifecycle only)
│   ├── AppCoordinator.swift           (~230 lines - main coordinator)
│   ├── ServiceContainer.swift         (~194 lines - DI container)
│   └── PushToTalkApp.swift
│
├── Coordinators/
│   ├── RecordingCoordinator.swift     (~440 lines - recording workflow)
│   └── SettingsCoordinator.swift      (~145 lines - settings management)
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── StatusBarViewModel.swift   (~115 lines)
│   │   ├── SettingsViewModel.swift    (~77 lines)
│   │   └── HistoryViewModel.swift     (~153 lines)
│   │
│   └── Views/
│       ├── MenuBar/
│       │   └── MenuBarController.swift (~328 lines)
│       ├── Settings/
│       │   ├── GeneralSettingsView.swift      (~125 lines)
│       │   ├── ModelSettingsView.swift        (~147 lines)
│       │   ├── HotkeySettingsView.swift       (~80 lines)
│       │   ├── VocabularySettingsView.swift   (~259 lines)
│       │   ├── AudioSettingsView.swift        (~109 lines)
│       │   ├── HistorySettingsView.swift      (~206 lines)
│       │   └── DebugSettingsView.swift        (~202 lines)
│       ├── Recording/
│       │   └── FloatingRecordingWindow.swift
│       └── Shared/
│           ├── VisualEffectBlur.swift         (~20 lines)
│           ├── SettingsCard.swift             (~38 lines)
│           └── SettingsHelpers.swift          (~46 lines)
│
├── Services/
│   ├── Protocols/
│   │   ├── WhisperServiceProtocol.swift
│   │   ├── AudioCaptureServiceProtocol.swift
│   │   ├── TextInserterProtocol.swift
│   │   └── KeyboardMonitorProtocol.swift
│   │
│   └── Implementation/
│       ├── WhisperService.swift
│       ├── AudioCaptureService.swift
│       ├── TextInserter.swift
│       ├── KeyboardMonitor.swift
│       └── AlertService.swift                 (~110 lines)
│
├── Managers/
│   ├── Protocols/
│   │   ├── ModelManagerProtocol.swift
│   │   ├── AudioDeviceManagerProtocol.swift
│   │   ├── VocabularyManagerProtocol.swift
│   │   └── HotkeyManagerProtocol.swift
│   │
│   └── Implementation/
│       ├── ModelManager.swift                 (~235 lines)
│       ├── AudioDeviceManager.swift           (~239 lines)
│       ├── VocabularyManager.swift            (~174 lines)
│       └── HotkeyManager.swift                (~270 lines)
│
├── Utils/
│   ├── Constants/
│   │   ├── AppConstants.swift                 (~160 lines)
│   │   ├── UIConstants.swift                  (~260 lines)
│   │   └── Strings.swift                      (~284 lines)
│   │
│   ├── Extensions/
│   │   ├── String+Extensions.swift            (~147 lines)
│   │   ├── Array+Extensions.swift             (~158 lines)
│   │   └── View+Extensions.swift              (~245 lines)
│   │
│   ├── Audio/
│   │   ├── AdaptiveVAD.swift
│   │   ├── AudioNormalizer.swift
│   │   ├── SilenceDetector.swift
│   │   ├── SpectralVAD.swift
│   │   └── VoiceActivityDetector.swift
│   │
│   ├── Media/
│   │   ├── AudioDuckingManager.swift
│   │   ├── AudioFeedbackManager.swift
│   │   ├── AudioPlayerManager.swift
│   │   ├── MediaRemoteManager.swift
│   │   ├── MicrophoneVolumeManager.swift
│   │   └── SoundManager.swift
│   │
│   └── Helpers/
│       ├── LogManager.swift
│       ├── NotificationManager.swift
│       ├── PermissionManager.swift
│       ├── TranscriptionHistory.swift
│       ├── UserSettings.swift
│       └── VocabularyDictionaries.swift
│
├── Domain/
│   ├── UseCases/                              (reserved for future)
│   └── Entities/                              (reserved for future)
│
└── UI/                                        (legacy - being phased out)
    └── ModernSettingsView.swift               (~390 lines - main container)
```

### System Logging

**LogManager** (`Sources/Utils/Helpers/LogManager.swift`)
- Unified logging system using Apple's OSLog framework
- Categories: `app`, `keyboard`, `audio`, `transcription`, `permissions`
- Subsystem: `com.pushtotalk.app`
- **Viewing logs**:
```bash
# Real-time log stream
log stream --predicate 'subsystem == "com.pushtotalk.app"'

# Filter by category
log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "keyboard"'

# Show last hour
log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h
```

### Constants and Localization

**Constants** (`Sources/Utils/Constants/`)
- **AppConstants**: App-wide settings (recording duration, model sizes, audio format, etc.)
- **UIConstants**: UI dimensions, spacing, colors, fonts, animations
- **Strings**: All user-facing text with NSLocalizedString support

**Localization** (`Resources/Localization/`)
- **English**: `en.lproj/Localizable.strings` (~150+ keys)
- **Russian**: `ru.lproj/Localizable.strings` (~150+ translations)
- Automatic language selection based on system preferences

### Permissions

**Required**:
- ✅ Microphone access (AVFoundation) - for audio recording

**NOT Required** (thanks to Carbon API):
- ❌ Accessibility - not needed for F-key hotkeys
- ❌ Input Monitoring - not needed for Carbon RegisterEventHotKey

**PermissionManager** (`Sources/Utils/PermissionManager.swift`)
- Simplified permission checker (microphone only)
- Async permission request with user feedback

## Development Tasks

### Building the Application

```bash
# Build the application
swift build

# Run the main executable
.build/debug/PushToTalkSwift

# Build release version
swift build -c release
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test executables
.build/debug/AudioCaptureTest
.build/debug/TranscribeTest
.build/debug/KeyboardMonitorTest
```

### Building .app Bundle

```bash
# Build signed .app with entitlements
./build_app.sh
```

## Common Issues & Debugging

### Hotkeys Not Working

**Problem**: Global hotkeys don't trigger recording

**Solutions**:
1. Check logs in Console.app:
   ```bash
   log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "keyboard"'
   ```
2. Carbon API does NOT require Accessibility permissions for F13-F19
3. If using modifier keys (Cmd/Option/Control), ensure they're not conflicting with system shortcuts
4. Verify hotkey registration in logs: look for "RegisterEventHotKey success"

### Missing Microphone Permission

**Problem**: Recording fails with permission error

**Solution**:
1. Open **System Settings** → **Privacy & Security** → **Microphone**
2. Enable **PushToTalk** in the list
3. Restart application

### Model Loading Fails

**Problem**: WhisperKit model download fails

**Solutions**:
1. Check internet connection (models downloaded from Hugging Face)
2. Verify Metal GPU availability:
   ```bash
   log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "transcription"'
   ```
3. Clear WhisperKit cache: `~/Library/Caches/whisperkit_models/`

### Viewing Application Logs

**Real-time monitoring**:
```bash
# All logs
log stream --predicate 'subsystem == "com.pushtotalk.app"' --level debug

# Only errors
log stream --predicate 'subsystem == "com.pushtotalk.app" && eventType >= logEventType.error'
```

**Historical logs**:
```bash
# Last 30 minutes
log show --predicate 'subsystem == "com.pushtotalk.app"' --last 30m

# Export to file
log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h > logs.txt
```

## Key Design Principles

### Architecture Principles

1. **Clean Architecture**: Clear separation of layers (Presentation, Coordination, Service, Manager, Infrastructure)
2. **Protocol-Oriented Programming**: All services and managers use protocols for dependency injection
3. **Dependency Injection**: Single ServiceContainer provides all dependencies, no singletons
4. **SOLID Principles**:
   - **Single Responsibility**: Each class has one clear purpose
   - **Open/Closed**: Extension through protocols, not modification
   - **Liskov Substitution**: Protocols enable interchangeable implementations
   - **Interface Segregation**: Narrow, focused protocols
   - **Dependency Inversion**: Depend on abstractions (protocols), not concrete classes
5. **MVVM Pattern**: Views separated from business logic via ViewModels
6. **Coordinator Pattern**: Navigation and workflow coordination separated from views

### Technical Principles

7. **Async/Await**: Modern concurrency with AsyncStream for events (hotkeys, audio chunks)
8. **Reactive Programming**: Combine framework with @Published properties
9. **Carbon API for Hotkeys**: More reliable than CGEventTap, no Accessibility permissions required
10. **Unified Logging**: All logs accessible through Console.app with proper categorization
11. **On-device Processing**: WhisperKit runs entirely on device with Metal GPU acceleration
12. **Minimal Permissions**: Only microphone access required, no Accessibility/Input Monitoring
13. **Performance Monitoring**: Real-Time Factor (RTF) tracking for transcription speed
14. **Menu Bar Only**: Runs as accessory app without Dock icon

### Code Quality

15. **DRY (Don't Repeat Yourself)**: All constants in dedicated files (AppConstants, UIConstants, Strings)
16. **No Magic Numbers**: All hardcoded values replaced with named constants
17. **No Hardcoded Strings**: All UI text in Strings.swift with localization support
18. **Small Files**: AppDelegate ~48 lines, Settings views ≤259 lines each
19. **Testability**: Protocol-based dependencies enable easy mocking

## Code References

### Core Architecture

- App lifecycle: `Sources/App/AppDelegate.swift` (~48 lines)
- Main coordinator: `Sources/App/AppCoordinator.swift:1` - Application startup and coordination
- Dependency injection: `Sources/App/ServiceContainer.swift:1` - DI container
- Recording workflow: `Sources/Coordinators/RecordingCoordinator.swift:1` - Recording logic
- Settings management: `Sources/Coordinators/SettingsCoordinator.swift:1` - Settings window

### Services (Protocol + Implementation)

- Keyboard monitoring: `Sources/Services/Implementation/KeyboardMonitor.swift:113` - Hotkey registration
- Carbon event handling: `Sources/Services/Implementation/KeyboardMonitor.swift:168` - Event processing
- AsyncStream hotkey events: `Sources/Services/Protocols/KeyboardMonitorProtocol.swift:12`
- Audio recording start: `Sources/Services/Implementation/AudioCaptureService.swift:41`
- AsyncStream audio chunks: `Sources/Services/Protocols/AudioCaptureServiceProtocol.swift:14`
- Transcription: `Sources/Services/Implementation/WhisperService.swift:62`
- WhisperService protocol: `Sources/Services/Protocols/WhisperServiceProtocol.swift:1`

### Managers (Protocol + Implementation)

- Model management: `Sources/Managers/Implementation/ModelManager.swift:1`
- Audio device management: `Sources/Managers/Implementation/AudioDeviceManager.swift:1`
- Vocabulary management: `Sources/Managers/Implementation/VocabularyManager.swift:1`
- Hotkey management: `Sources/Managers/Implementation/HotkeyManager.swift:1`

### ViewModels

- Status bar state: `Sources/Presentation/ViewModels/StatusBarViewModel.swift:1`
- Settings state: `Sources/Presentation/ViewModels/SettingsViewModel.swift:1`
- History state: `Sources/Presentation/ViewModels/HistoryViewModel.swift:1`

### Utilities

- Logging: `Sources/Utils/Helpers/LogManager.swift:1` - OSLog configuration
- Constants: `Sources/Utils/Constants/AppConstants.swift:1` - App-wide settings
- UI Constants: `Sources/Utils/Constants/UIConstants.swift:1` - UI dimensions
- Localization: `Sources/Utils/Constants/Strings.swift:1` - NSLocalizedString
- String extensions: `Sources/Utils/Extensions/String+Extensions.swift:1`
- Array extensions: `Sources/Utils/Extensions/Array+Extensions.swift:1`
- View extensions: `Sources/Utils/Extensions/View+Extensions.swift:1`
