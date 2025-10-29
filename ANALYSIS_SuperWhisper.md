# Детальный анализ SuperWhisper - Reverse Engineering отчет

## Общая информация

**Приложение**: SuperWhisper v2.6.2
**Bundle ID**: com.superduper.superwhisper
**Платформа**: macOS 13.3+, Universal Binary (x86_64 + arm64)
**Язык разработки**: Swift + SwiftUI
**Компилятор**: Xcode 26.0 (17A324)

---

## 1. Архитектура и технологический стек

### 1.1 Основные фреймворки

**ML/AI компоненты:**
- **GGML** (Georgi Gerganov ML) - библиотека для машинного обучения с Metal GPU ускорением
  - `libggml-metal.dylib` (570 KB) - GPU ускорение через Metal
  - `libggml-cpu.dylib` (1 MB) - CPU fallback
  - `libggml-base.dylib`, `libggml-blas.dylib`, `libggml-rpc.dylib`
  - Поддержка LORA merged моделей

- **ONNX Runtime** v1.19.0 (52 MB) - для VAD (Voice Activity Detection)
- **WhisperKit** - Swift обертка над Whisper моделями
- **ArgmaxSDK.framework** - проприетарный SDK для расширенной функциональности

**Аудио обработка:**
- **AVFoundation/AVFAudio** - запись микрофона
- **SimplyCoreAudio** - управление аудио устройствами
- **CoreAudio** - низкоуровневая работа с аудио
- **YbridOgg/YbridOpus** - кодеки для сжатия аудио

**Системная интеграция:**
- **Carbon API** - для глобальных hotkey без Accessibility разрешений
- **MediaRemote.framework** (Private API) - контроль медиа воспроизведения
- **Accessibility API** - для вставки текста в активное приложение
- **Contacts.framework** - интеграция с контактами

**Networking & Analytics:**
- **CFNetwork** - сетевые запросы
- **Starscream** - WebSocket клиент
- **Sentry SDK** - crash reporting и аналитика
- **Sparkle** v2.6.4 - автообновления

---

## 2. Ключевые архитектурные решения

### 2.1 Система горячих клавиш (Hotkeys)

**Файлы:**
- `CarbonKeyboardShortcuts.swift` - Carbon API интеграция
- `KeyShortcut.swift` - модель для горячих клавиш
- `HIDManager.swift` - Human Interface Device управление
- `ShortcutManager.swift` - центральный менеджер

**Особенности:**
- Использование **Carbon Event Manager API** (`RegisterEventHotKey`)
- **Преимущество**: НЕ требует Accessibility разрешений для F-клавиш (F13-F19)
- Поддержка модификаторов: Right Cmd/Option/Control
- Динамическая перерегистрация при смене hotkey пользователем
- Обработчики: `handleCarbonEvent()`, `onKeyDown()`

**Код-паттерн:**
```
Error registering hotkey
Created KeyShortcut from display string
```

### 2.2 Voice Activity Detection (VAD)

**Реализации:**
- **SileroVAD** - ONNX модель для определения речи
- **EnergyVAD** - простой энергетический детектор
- **VADAudioChunker** - разбивка аудио на сегменты

**Параметры конфигурации:**
```
VAD_THRESHOLD
VAD_WINDOW_SIZE_MS
VAD_MIN_SILENCE_DURATION_MS
VAD_MIN_SPEECH_DURATION_MS
SILENCE_TOLERANCE
```

**URL модели VAD:**
```
https://models.superwhisper.com/vad-v1.onnx
```

### 2.3 Аудио пайплайн

**Компоненты:**
- `CaptureEngine.swift` - захват с микрофона/системного аудио
- `ScreenRecorder.swift` - запись системного аудио
- `Recorder.swift` - высокоуровневый рекордер
- `AudioBackend.swift` - абстракция над AVAudioEngine
- `AudioDeviceManager.swift` - управление устройствами через SimplyCoreAudio
- `WavOps.swift` - операции с WAV файлами

**Особенности:**
- Поддержка записи с микрофона и системного аудио
- Автоматическое управление громкостью (fade in/out)
- Автоматическое переключение устройств
- Обработка буферов с thread-safe операциями

### 2.4 Вставка текста (Text Insertion)

**Файлы:**
- `AxManager.swift` - Accessibility API менеджер
- `ClipboardManager.swift` - работа с clipboard
- `PasteboardManager.swift` - низкоуровневая работа с pasteboard
- `AppleScriptManager.swift` - автоматизация через AppleScript

**Методы вставки:**
1. **Через Accessibility API** - прямая вставка в текстовое поле
2. **Через Clipboard** - копирование в буфер + симуляция Cmd+V
3. **Через AppleScript** - для специфичных приложений

**Контекстное определение приложения:**
- `bundled_app_info.json` - база данных >150 приложений с метаданными
- Определение формата вставки: `plaintext`, `rich_text`, `markdown`, `code`, `email`, и т.д.

### 2.5 UI/UX компоненты

**Аудио фидбек:**
- **Start1-4.m4a** (33-34 KB) - звук начала записи (4 варианта)
- **Stop1-4.m4a** (33-34 KB) - звук остановки записи
- **Loop.m4a** (558 KB) - фоновый звук во время записи
- **noResult1-4.m4a** (92-93 KB) - звук при отсутствии результата
- **Intro.m4a** (322 KB) - интро звук

**Менеджеры:**
- `SoundEffectManager.swift` - управление звуковыми эффектами
- `AudioPlayerEngine.swift` - воспроизведение аудио

---

## 3. Whisper модели и транскрипция

### 3.1 Поддерживаемые модели

**Обнаруженные упоминания:**
- Whisper Fast (английский и мультиязычный)
- Whisper Standard (английский и мультиязычный)
- Whisper Pro (высокое качество)
- Whisper Ultra (новейшая версия)
- **Nvidia Parakeet V3** - поддержка 24 языков
- Cloud transcription через API

### 3.2 Транскрипция

**Компоненты:**
- `WhisperKitManager` - менеджер WhisperKit
- `WhisperTokenizer` - токенизация
- `BeamSearchTokenSampler` - beam search декодинг
- `LanguageLogitsFilter` - фильтрация языков
- `TranscriptionUtilities` - вспомогательные утилиты

**Данные транскрипции:**
```swift
TranscriptionResult
TranscriptionSegment
TranscriptionProgress
TranscriptionState
TranscriptionTimings
```

**Функции:**
- Автоопределение языка
- Мультиязычная поддержка
- Beam search для улучшения качества
- Прогресс транскрипции

---

## 4. Менеджеры и сервисы

### 4.1 Центральные менеджеры

**Файловая структура:**
```
Managers/
├── ActiveRecordingManager.swift    - управление активными записями
├── APIManager.swift                - API запросы
├── AppInfoManager.swift            - информация о приложениях
├── AppleScriptManager.swift        - AppleScript автоматизация
├── ClipboardManager.swift          - clipboard операции
├── FilesyncManager.swift           - синхронизация файлов
├── HistoryManager.swift            - история транскрипций
├── KeyboardLayoutManager.swift     - раскладки клавиатуры
├── LicenseManager.swift            - лицензирование
├── ModelManager.swift              - управление ML моделями
├── ModeManager.swift               - режимы работы
├── PasteboardManager.swift         - pasteboard операции
├── ReportUploadManager.swift       - отправка отчетов
├── ScreenWakeManager.swift         - предотвращение сна экрана
├── SettingsManager.swift           - настройки
├── ShortcutManager.swift           - горячие клавиши
└── SystemManager.swift             - системные операции
```

### 4.2 Дополнительные компоненты

- `CloudState.swift` - состояние облачной синхронизации
- `MusicManager.swift` - интеграция с медиа плеером
- `MediaRemote.swift` - MediaRemote API обертка
- `PromptRenderer.swift` - рендеринг промптов для LLM

---

## 5. Permissions & Entitlements

### 5.1 Требуемые разрешения

**Обязательные:**
- `com.apple.security.device.audio-input` - запись микрофона
- `com.apple.security.automation.apple-events` - AppleScript автоматизация

**Опциональные:**
- Accessibility - для вставки текста в некоторые приложения
- Screen Recording - для захвата системного аудио

**НЕ требуется:**
- Input Monitoring - благодаря Carbon API для hotkeys

### 5.2 Info.plist ключи

```xml
NSMicrophoneUsageDescription: "Needed to record your voice"
NSAccessibilityUsageDescription: "Needed to paste into input fields once audio has been processed"
NSAppleEventsUsageDescription: "Needed to paste into input fields once audio has been processed"
```

**Sparkle автообновления:**
```xml
SUFeedURL: https://superwhisper.com/appcast.xml
SUPublicEDKey: LaNqajeJmIalBugxXQ/11U9E7xKcnzBiVMsY1DkpWQM=
SUScheduledCheckInterval: 86400 (24 часа)
```

---

## 6. Полезные находки для нашего проекта

### 6.1 Критически важные улучшения

**1. Voice Activity Detection (VAD)**
- Использование Silero VAD через ONNX Runtime
- Автоматическое определение начала/конца речи
- Параметры: window size, min silence/speech duration
- **Применение**: Избавиться от необходимости держать hotkey

**2. Аудио фидбек**
- 4 варианта звуков для start/stop/noResult
- Loop звук во время записи
- **Применение**: Улучшить UX нашего приложения

**3. База приложений (bundled_app_info.json)**
- >150 приложений с метаданными
- Определение формата вставки текста
- Категоризация по типам
- **Применение**: Контекстная вставка текста

**4. MediaRemote интеграция**
- `mediaremote-adapter.pl` - Perl скрипт для управления
- Автоматическое pause/resume медиа при записи
- **Применение**: Автопауза музыки при диктовке

**5. Управление аудио устройствами**
- SimplyCoreAudio для device management
- Fade in/out громкости
- Автопереключение устройств
- **Применение**: Профессиональная обработка аудио

### 6.2 Архитектурные паттерны

**1. Carbon API для hotkeys**
- НЕ требует Accessibility разрешений
- Поддержка F13-F19 + модификаторы
- Динамическая перерегистрация
- **Код**: `CarbonKeyboardShortcuts.swift`

**2. Менеджеры-синглтоны**
- Централизованное управление подсистемами
- Четкое разделение ответственности
- **Паттерн**: `ShortcutManager`, `ModelManager`, `AudioDeviceManager`

**3. Комбинированная вставка текста**
- Accessibility API (приоритет)
- Clipboard fallback
- AppleScript для edge cases
- **Код**: `AxManager.swift`, `ClipboardManager.swift`

### 6.3 ML/AI стек

**1. GGML + Metal**
- GPU ускорение через Metal
- Поддержка LORA merged моделей
- CPU fallback
- **Размер**: ~3.5 MB библиотек

**2. ONNX Runtime**
- VAD модель
- Быстрая инференция
- **Размер**: 52 MB

**3. WhisperKit**
- Swift-нативная интеграция
- Beam search декодинг
- Мультиязычность

### 6.4 UX/UI элементы

**1. Аудио обратная связь**
- Множественные варианты звуков (рандомизация)
- Loop во время записи
- Звук при отсутствии результата

**2. SwiftUI компоненты**
- `AuxPanelView` - вспомогательная панель
- `MinimizeRecordingWindowView` - минималистичное окно
- Menu bar интеграция

---

## 7. Рекомендации по внедрению

### Приоритет 1 (критично)

1. **VAD интеграция**
   - Добавить Silero VAD через ONNX Runtime
   - Параметры: threshold, window size, min silence/speech duration
   - Автоматическое определение конца речи

2. **Аудио фидбек**
   - Добавить звуки start/stop/loop/noResult
   - Рандомизация между вариантами

3. **MediaRemote**
   - Автопауза музыки при начале записи
   - Возобновление после транскрипции

### Приоритет 2 (важно)

4. **Контекстная вставка**
   - База приложений с форматами
   - Определение активного приложения
   - Выбор метода вставки (Accessibility/Clipboard/AppleScript)

5. **Аудио устройства**
   - SimplyCoreAudio интеграция
   - Fade in/out громкости
   - Автопереключение устройств

### Приоритет 3 (опционально)

6. **Sparkle автообновления**
   - Интеграция фреймворка
   - Настройка appcast feed

7. **Sentry analytics**
   - Crash reporting
   - Performance monitoring

---

## 8. Выводы

SuperWhisper - профессионально разработанное приложение с продуманной архитектурой:

**Сильные стороны:**
- Использование современных технологий (WhisperKit, GGML, Metal)
- Отличный UX (аудио фидбек, VAD, контекстная вставка)
- Минимальные требования к разрешениям (Carbon API)
- Масштабируемая архитектура (менеджеры, сервисы)

**Что можем взять:**
- VAD для автоматического определения конца речи
- Аудио фидбек для улучшения UX
- MediaRemote для автопаузы музыки
- База приложений для контекстной вставки
- SimplyCoreAudio для профессиональной работы с аудио

**Что уже лучше в нашем проекте:**
- Более простая и понятная архитектура
- Нативный Swift без сторонних SDK
- Меньше зависимостей
