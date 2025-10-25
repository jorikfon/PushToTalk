# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PushToTalk** is a lightweight voice-to-text application optimized for Apple Silicon (M1/M2/M3). It uses customizable hotkeys (default: F16) as a push-to-talk trigger and automatically inserts recognized speech at the current cursor position.

The application is built with **Swift** and uses **WhisperKit** for on-device speech recognition with Metal GPU acceleration.

## Architecture

### Core Services

#### 1. KeyboardMonitor (`Sources/Services/KeyboardMonitor.swift`)
- **Technology**: Carbon Event Manager API (`RegisterEventHotKey`)
- **Advantage**: Does NOT require Accessibility permissions for function keys (F13-F19)
- **Features**:
  - Supports F13-F19 and modifier keys (Right Cmd/Option/Control)
  - Automatic hotkey re-registration when user changes preference
  - Global event monitoring without Input Monitoring permissions
- **Key Methods**:
  - `startMonitoring()` - Registers global hotkey with Carbon Event Manager
  - `handleCarbonEvent()` - Processes kEventHotKeyPressed/Released events
  - `restartMonitoring()` - Re-registers hotkey when changed

#### 2. AudioCaptureService (`Sources/Services/AudioCaptureService.swift`)
- Audio capture using AVAudioEngine
- Real-time format conversion: native microphone format → 16kHz mono Float32
- Buffer management with thread-safe locking
- **Key Methods**:
  - `startRecording()` - Starts AVAudioEngine with format conversion pipeline
  - `stopRecording()` - Returns captured audio samples
  - `processAudioBuffer()` - Converts and buffers audio chunks

#### 3. WhisperService (`Sources/Services/WhisperService.swift`)
- WhisperKit integration for on-device transcription
- Metal GPU acceleration through MLX backend
- Performance metrics (Real-Time Factor, transcription speed)
- **Key Methods**:
  - `loadModel()` - Downloads and initializes WhisperKit model
  - `transcribe()` - Transcribes audio samples to text
  - `verifyMetalAcceleration()` - Checks Metal GPU availability

#### 4. HotkeyManager (`Sources/Utils/HotkeyManager.swift`)
- Centralized hotkey configuration management
- Persists user hotkey preference to UserDefaults
- Notifies KeyboardMonitor when hotkey changes
- Supported keys: F13-F19, Right Command/Option/Control

### System Logging

**LogManager** (`Sources/Utils/LogManager.swift`)
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

1. **Carbon API for Hotkeys**: More reliable than CGEventTap, no Accessibility permissions required
2. **Unified Logging**: All logs accessible through Console.app with proper categorization
3. **On-device Processing**: WhisperKit runs entirely on device with Metal GPU acceleration
4. **Minimal Permissions**: Only microphone access required, no Accessibility/Input Monitoring
5. **Performance Monitoring**: Real-Time Factor (RTF) tracking for transcription speed
6. **Menu Bar Only**: Runs as accessory app without Dock icon

## Code References

- Hotkey registration: `Sources/Services/KeyboardMonitor.swift:113`
- Carbon event handling: `Sources/Services/KeyboardMonitor.swift:168`
- Audio recording start: `Sources/Services/AudioCaptureService.swift:41`
- Transcription: `Sources/Services/WhisperService.swift:62`
- Log viewer instructions: `Sources/Utils/LogManager.swift:69`
