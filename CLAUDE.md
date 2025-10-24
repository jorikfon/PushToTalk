# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PushToTalk** is a lightweight voice-to-text application optimized for Apple Silicon (M1/M2/M3). It uses the F16 key as a push-to-talk trigger and automatically inserts recognized speech at the current cursor position.

The project provides three implementation variants:
- **Native**: Uses macOS native Speech Framework (lightweight, no AI models)
- **Whisper**: Uses OpenAI's Whisper for accurate speech recognition
- **Core ML**: Uses Core ML format on Apple Neural Engine (zero CPU idle, M1-optimized)

## Architecture

### Core Components

**CoreMLPushToTalk class** (`push_to_talk_coreml.py:22-262`)
- Main application class managing the lifecycle and state
- Key responsibilities:
  - Audio capture and buffering via `sounddevice` library
  - Model loading/conversion to Core ML format
  - Keyboard listener for F16 press/release events
  - Text insertion at cursor via clipboard manipulation

**Key Methods:**
- `load_coreml_model()` - Loads or converts Whisper model to Core ML format (cached in `/tmp`)
- `start_recording()` - Initializes audio stream and background processing thread
- `_process_audio_queue()` - Background worker thread that buffers audio chunks
- `stop_recording_and_transcribe()` - Stops recording, runs inference on Neural Engine, inserts text
- `insert_text_at_cursor()` - Uses clipboard to paste text and `pynput` keyboard control

### Dependencies

**Core libraries:**
- `sounddevice` - Audio input capture with callback-based architecture
- `coremltools` - Convert PyTorch models to Core ML format
- `transformers` - Whisper model and processor from HuggingFace
- `torch` - PyTorch runtime for model conversion
- `pynput` - Cross-platform keyboard/mouse control
- `pyperclip` - Clipboard access for text insertion

**Model details:**
- Uses `WhisperForConditionalGeneration` from OpenAI
- Mel spectrogram input: shape (1, 80, 3000)
- Currently defaults to 'tiny' model for M1 efficiency
- Models are converted to Core ML on first run and cached in `/tmp`

### Audio Pipeline

1. `start_recording()` creates an audio stream with 512 sample buffer (low latency)
2. Samples are fed to `audio_callback()` which enqueues chunks into `audio_queue`
3. Background thread `_process_audio_queue()` pulls chunks and concatenates them
4. On F16 release, audio is flattened and processed:
   - Mel spectrogram computed by Whisper processor
   - Inference run on Neural Engine via Core ML
   - Output tokens decoded back to text
   - Text inserted via clipboard + Cmd+V

### macOS Integration

- **F16 key detection**: Uses `pynput.keyboard.Listener` with vk=127 (F16 keycode)
- **Text insertion**: Copies text to clipboard, presses Cmd+V via `pynput` controller
- **Audio feedback**: Uses `afplay` for sound effects (`Pop.aiff`, `Glass.aiff`, `Basso.aiff`)
- **Fallback**: macOS dictation via AppleScript if Core ML inference fails
- **Process optimization**: Runs on efficiency cores via `taskpolicy` background mode

## Development Tasks

### Setup for Development

```bash
# Run setup wizard (interactive)
bash setup_m1.sh

# Manual dependency installation for Core ML variant
pip3 install coremltools sounddevice transformers torch soundfile pyperclip pynput numpy
```

### Running the Application

```bash
# Run Core ML variant (M1-optimized)
python3 push_to_talk_coreml.py

# Controls:
# F16: Hold to record, release to transcribe and insert
# ESC: Exit application
```

### Testing

The setup script includes an interactive test (`test_setup()` in `setup_m1.sh`) that validates:
- Python package imports
- Microphone device availability
- Clipboard access
- F16 key detection

Run manually:
```bash
bash setup_m1.sh  # Select option to run tests
```

## Common Issues & Debugging

**Model Loading**: First run converts Whisper model to Core ML format (large download, one-time only). Cached in `/tmp/whisper_tiny.mlmodel`.

**Missing Permissions**: The script requires:
1. **Accessibility** permission for keyboard control
2. **Microphone** permission for audio input
3. **Input Monitoring** permission for F16 key detection

Grant via System Settings > Privacy & Security.

**Inference Failures**: If Core ML prediction fails, the application falls back to macOS native dictation via AppleScript.

## Key Design Principles

1. **Zero idle CPU**: Neural Engine handles inference, main process sleeps until F16 pressed
2. **Minimal latency**: 512-sample buffer, background thread for audio processing
3. **Clipboard safety**: Original clipboard contents restored after 300ms delay
4. **Audio feedback**: System sounds (Pop, Glass, Basso) for user feedback
5. **M1 optimization**: Process priority set to efficiency cores, QoS background
