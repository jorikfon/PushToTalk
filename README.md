# PushToTalk - Voice-to-Text for macOS

<div align="center">

🎤 **Легковесное приложение для голосового ввода, оптимизированное для Apple Silicon (M1/M2/M3)**

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)]()
[![Swift](https://img.shields.io/badge/Swift-6.2-orange)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()

</div>

---

## ✨ Возможности

- 🎤 **Приложение в Menu Bar** - Чистый нативный macOS интерфейс
- ⌨️ **Настраиваемые горячие клавиши** - F13-F19, Right Cmd/Option/Control
- 🪟 **Liquid Glass UI** - Минималистичное всплывающее окно с эффектом стекла
- 🧠 **WhisperKit Integration** - OpenAI Whisper на Apple Neural Engine
- 🚀 **Оптимизация для Apple Silicon** - Metal ускорение, нулевая нагрузка в режиме ожидания
- 📝 **Автоматическая вставка текста** - Текст появляется в позиции курсора
- 🛑 **Стоп-слово "отмена"** - Сброс записи на лету
- 🔊 **Звуковая обратная связь** - Системные звуки для различных состояний
- 🌍 **Мультиязычность** - Русский, английский и множество других языков
- ⚡ **Быстро и легковесно** - Нативный Swift, без накладных расходов Python
- 🎧 **Smart Audio Ducking** - Автоматическое приглушение музыки во время записи
- 📁 **Транскрипция файлов** - Batch обработка аудио файлов с диалоговым режимом
- 🎭 **Стерео диалоги** - Автоматическое разделение на двух спикеров (левый/правый канал)
- 📊 **Timeline View** - Визуализация диалога с временной синхронизацией
- 🎯 **Voice Activity Detection (VAD)** - 7+ алгоритмов для точного разбиения на сегменты
- 🎵 **Audio Player** - Встроенный плеер для прослушивания результатов

---

## 🎯 Как это работает

1. **Нажмите F16** (или настроенную горячую клавишу) - появится окно с подсказкой
2. **Говорите** - видите распознанный текст в реальном времени
3. **Скажите "отмена"** - если нужно начать заново (буфер сбросится)
4. **Отпустите F16** - текст вставится в позицию курсора, окно исчезнет

### Особенности интерфейса

- **Liquid Glass эффект** - красивое размытое стекло по Apple Design Guidelines
- **Минималистичный дизайн** - только необходимое, без лишних элементов
- **Пульсирующая точка записи** - единственная анимация, показывающая активность
- **Автоматическое исчезновение** - окно закрывается сразу после вставки текста

---

## 🏗️ Архитектура

**PushToTalk** построен на современных технологиях Apple:

- **Swift 6.2** - Современный, типобезопасный язык
- **WhisperKit** - Whisper inference на Apple Silicon
- **AVFoundation** - Захват аудио (16kHz mono)
- **SwiftUI** - Реактивные UI компоненты
- **AppKit** - Интеграция с menu bar
- **Carbon Event Manager** - Глобальные горячие клавиши БЕЗ Accessibility разрешений

### Технологический стек

| Компонент | Технология |
|-----------|------------|
| Язык | Swift 6.2 |
| ML Framework | WhisperKit (MLX-based) |
| Аудио | AVFoundation |
| Горячие клавиши | Carbon Event Manager API |
| UI | SwiftUI + AppKit |
| Сборка | Swift Package Manager |

---

## 🚀 Быстрый старт

### Требования

- macOS 14.0 (Sonoma) или новее
- Apple Silicon (M1/M2/M3)
- Xcode Command Line Tools

### Сборка

```bash
# Клонируйте репозиторий
git clone https://github.com/jorikfon/PushToTalk.git
cd PushToTalk

# Соберите проект
swift build

# Или создайте .app bundle
./build_app.sh

# Запустите приложение
open build/PushToTalk.app
```

### Первый запуск

При первом запуске macOS запросит разрешения:

1. **Микрофон** - Требуется для записи аудио
   - Системные настройки → Конфиденциальность и безопасность → Микрофон
   - ✅ Включите **PushToTalk**

2. **Accessibility** - Требуется только для вставки текста
   - Системные настройки → Конфиденциальность и безопасность → Универсальный доступ
   - ✅ Включите **PushToTalk**

**Примечание**: Для мониторинга F-клавиш (F13-F19) Accessibility НЕ требуется благодаря использованию Carbon API!

---

## 📖 Использование

### Интерфейс Menu Bar

Найдите иконку **🎤** в menu bar (правый верхний угол):

- **🎤** - Готов к записи
- **🎤 (filled)** - Идет запись
- **⚙️** - Идет обработка

**Нажмите на иконку** чтобы открыть настройки:
- Выбор модели Whisper (Tiny/Base/Small/Medium/Large)
- Выбор горячей клавиши (F13-F19, Right Cmd/Option/Control)
- Multilingual режим (автоопределение языка)
- Автоматическая вставка EarPods подсказки
- Транскрипция аудио файлов (drag & drop или файловый диалог)
- Выбор VAD алгоритма (Spectral/Adaptive/Standard)
- Настройка пользовательских словарей
- Индикатор статуса записи
- История транскрипций
- Кнопка выхода

### Транскрипция файлов

Drag & drop или выберите аудио файлы:
- **Mono файлы** - Обычная текстовая транскрипция
- **Stereo файлы** - Автоматическое разделение на диалог (Speaker 1 / Speaker 2)
- **Timeline View** - Визуализация диалога с временной синхронизацией
- **VAD режимы** - Voice Activity Detection или Batch (фиксированные чанки)
- **7+ VAD алгоритмов** - Spectral (FFT), Adaptive (порог), Standard (энергия)
- **Audio Player** - Воспроизведение с переходом к конкретной реплике
- **Автоматическое сжатие** - Удаление периодов тишины (>2 сек)

### Горячие клавиши

По умолчанию: **F16**

Поддерживаются:
- **F13-F19** - Не требуют Accessibility разрешений!
- **Right Command** - Правый ⌘
- **Right Option** - Правый ⌥
- **Right Control** - Правый ⌃

### Команда "отмена"

Если вы видите неправильно распознанный текст:

1. Сделайте **паузу**
2. Скажите **"отмена"**
3. Буфер сбросится, текст очистится
4. Продолжайте говорить заново

Или просто отпустите F16 после "отмена" - текст не вставится.

### Звуковая обратная связь

- **Pop** 🎵 - Запись началась
- **Tink** 🔔 - Запись остановлена / отмена
- **Glass** ✨ - Транскрипция успешна
- **Basso** ❌ - Ошибка транскрипции

---

## 📂 Структура проекта

```
PushToTalk/
├── Package.swift                          # Конфигурация Swift Package Manager
├── build_app.sh                           # Скрипт сборки .app bundle
├── Sources/
│   ├── App/
│   │   ├── PushToTalkApp.swift           # @main точка входа
│   │   └── AppDelegate.swift              # Жизненный цикл приложения
│   ├── Services/
│   │   ├── AudioCaptureService.swift     # Запись аудио (16kHz mono)
│   │   ├── WhisperService.swift          # Интеграция WhisperKit
│   │   ├── KeyboardMonitor.swift         # Глобальный мониторинг F16 (Carbon API)
│   │   ├── TextInserter.swift            # Вставка текста через clipboard
│   │   ├── FileTranscriptionService.swift # Batch транскрипция файлов
│   │   └── BatchTranscriptionService.swift # Стерео диалоги
│   ├── UI/
│   │   ├── MenuBarController.swift       # Интерфейс menu bar
│   │   ├── FloatingRecordingWindow.swift # Liquid Glass всплывающее окно
│   │   ├── ModernSettingsView.swift      # Современные настройки
│   │   ├── FileTranscriptionWindow.swift # Окно транскрипции файлов
│   │   └── SettingsWindowController.swift # Контроллер окна настроек
│   └── Utils/
│       ├── PermissionManager.swift       # Управление разрешениями
│       ├── SoundManager.swift            # Звуковая обратная связь
│       ├── HotkeyManager.swift           # Управление горячими клавишами
│       ├── ModelManager.swift            # Управление моделями Whisper
│       ├── AudioDuckingManager.swift     # Приглушение музыки
│       ├── MediaRemoteManager.swift      # Управление воспроизведением медиа
│       ├── TranscriptionHistory.swift    # История транскрипций
│       ├── UserSettings.swift            # Пользовательские настройки
│       ├── SpectralVAD.swift             # FFT-based Voice Activity Detection
│       ├── AdaptiveVAD.swift             # Adaptive VAD с автоматическим порогом
│       ├── AudioPlayerManager.swift      # Аудио плеер для файлов
│       ├── LogManager.swift              # Унифицированное логирование (OSLog)
│       └── NotificationManager.swift     # Системные уведомления
├── Resources/
│   ├── Info.plist                        # Метаданные приложения
│   └── PushToTalk.entitlements          # Разрешения приложения
└── CLAUDE.md                             # Инструкции для разработки
```

---

## 🛠️ Разработка

### Доступные цели сборки

```bash
# Основное приложение
swift build --product PushToTalkSwift

# Тестовые исполняемые файлы
swift build --product AudioCaptureTest      # Тест захвата аудио
swift build --product KeyboardMonitorTest   # Тест мониторинга F16
swift build --product TextInserterTest      # Тест вставки текста
swift build --product IntegrationTest       # Полный pipeline тест
swift build --product PerformanceBenchmark  # Бенчмарк производительности
swift build --product VADTest               # Тест VAD алгоритмов
```

### Запуск тестов

```bash
# Тест захвата аудио (записывает 3 секунды)
.build/debug/AudioCaptureTest

# Тест мониторинга клавиатуры (нажмите F16 для теста)
.build/debug/KeyboardMonitorTest

# Тест вставки текста (вставляет тестовый текст)
.build/debug/TextInserterTest

# Интеграция тест (микрофон → транскрипция)
.build/debug/IntegrationTest

# Бенчмарк производительности
.build/debug/PerformanceBenchmark

# Тест VAD алгоритмов (требует аудио файл)
.build/debug/VADTest /path/to/audio.mp3
```

### Просмотр логов

Все логи доступны через Console.app с subsystem `com.pushtotalk.app`:

```bash
# Real-time лог
log stream --predicate 'subsystem == "com.pushtotalk.app"' --level debug

# Фильтр по категории
log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "keyboard"'

# Последний час
log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h

# Экспорт в файл
log show --predicate 'subsystem == "com.pushtotalk.app"' --last 1h > logs.txt
```

### Чистая сборка

```bash
swift package clean
swift build
```

---

## 🔧 Технические детали

### Audio Pipeline

1. **Capture** - AVAudioEngine захватывает микрофон (нативный формат)
2. **Convert** - AVAudioConverter ресемплирует в 16000 Hz mono Float32
3. **Buffer** - Аудио сэмплы хранятся как Float32 массив
4. **Real-time** - Чанки по 2 секунды отправляются на транскрипцию
5. **Process** - WhisperKit обрабатывает финальный буфер

### Whisper Integration

- **Модели**: Tiny (~150 MB), Base (~300 MB), Small (~600 MB), Medium (~1.5 GB), Large (~3 GB)
- **Framework**: WhisperKit (MLX-based)
- **Устройство**: Apple Neural Engine + GPU (Metal)
- **Формат**: 16kHz mono Float32
- **Скорость**: ~5-10x реального времени на M1 Max
- **Multilingual**: Автоопределение языка (опционально)

### Мониторинг клавиатуры

**Два метода**:

1. **Carbon Event Manager** (основной, для F13-F19)
   - `RegisterEventHotKey` API
   - НЕ требует Accessibility разрешений
   - Работает только с F-клавишами и модификаторами
   - Более надежный, меньше конфликтов

2. **CGEvent Tap** (fallback, для других клавиш)
   - Глобальный event tap
   - Требует Accessibility разрешения
   - Работает с любыми клавишами

### Вставка текста

Два метода реализованы:

1. **Clipboard + Cmd+V** (основной)
   - Сохраняет оригинальный clipboard
   - Копирует транскрипцию
   - Симулирует Cmd+V через CGEvent
   - Восстанавливает clipboard через 300ms

2. **Accessibility API** (fallback)
   - Прямая вставка через AXUIElement
   - Используется когда clipboard метод не работает

### Audio Ducking

- Автоматически приглушает музыку на 50% при начале записи
- Восстанавливает громкость после завершения
- Работает через `kAudioDevicePropertyVolumeScalar`

---

## 📊 Производительность

### Бенчмарки (M1 Max, Whisper Tiny)

| Метрика | Значение |
|---------|----------|
| Размер .app | ~4.7 MB |
| Размер модели | ~150 MB (Tiny) |
| Холодный старт | ~2-3 секунды (загрузка модели) |
| Теплый старт | <1 секунды |
| Память в режиме ожидания | ~90 MB |
| Память при записи | ~120 MB |
| Память при транскрипции | ~200 MB (пик) |
| Скорость транскрипции | ~5-10x реального времени |
| Real-Time Factor (RTF) | ~0.1-0.2 |

### Эксперименты с моделями

Полные бенчмарки доступны в `Experiments/`:

```bash
# Запустить сравнение моделей
.build/debug/ModelComparison
```

---

## 🐛 Устранение неполадок

### Приложение не запускается

1. Проверьте сборку: `swift build`
2. Запустите напрямую: `.build/debug/PushToTalkSwift`
3. Проверьте системные логи:
   ```bash
   log show --predicate 'subsystem == "com.pushtotalk.app"' --last 5m
   ```

### "This process is not trusted"

Нормально при первом запуске! Добавьте Accessibility разрешение:
1. Системные настройки → Конфиденциальность и безопасность → Универсальный доступ
2. Нажмите `+` → Выберите `.build/debug/PushToTalkSwift`
3. Перезапустите приложение

### Аудио не захватывается

1. Проверьте разрешение микрофона в Системных настройках
2. Тест с AudioCaptureTest: `.build/debug/AudioCaptureTest`
3. Убедитесь, что микрофон работает в других приложениях
4. Проверьте логи:
   ```bash
   log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "audio"'
   ```

### Текст не вставляется

1. Проверьте Accessibility разрешение
2. Убедитесь, что курсор в текстовом поле
3. Тест с TextInserterTest: `.build/debug/TextInserterTest`

### F16 не работает

1. Проверьте логи:
   ```bash
   log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "keyboard"'
   ```
2. Carbon API НЕ требует Accessibility для F13-F19
3. Убедитесь, что F16 не назначена на другое действие в системе
4. Попробуйте другую F-клавишу (F13-F19)

### Модель не загружается

1. Проверьте интернет-соединение (модели загружаются с Hugging Face)
2. Проверьте доступность Metal GPU:
   ```bash
   log stream --predicate 'subsystem == "com.pushtotalk.app" && category == "transcription"'
   ```
3. Очистите кэш: `~/Library/Caches/whisperkit_models/`
4. Попробуйте другую модель (Tiny самая маленькая)

---

## 🎯 Roadmap

### Завершено ✅
- [x] Исследование WhisperKit и proof-of-concept
- [x] Захват аудио (AVFoundation)
- [x] Транскрипция Whisper (WhisperKit)
- [x] Мониторинг F16 (Carbon API + CGEvent)
- [x] Вставка текста (Clipboard + Accessibility)
- [x] Menu bar UI (SwiftUI + AppKit)
- [x] Liquid Glass всплывающее окно
- [x] Звуковая обратная связь
- [x] Управление разрешениями
- [x] Настраиваемые горячие клавиши (F13-F19, Right Cmd/Option/Control)
- [x] Выбор модели Whisper (Tiny/Base/Small/Medium/Large)
- [x] Multilingual режим
- [x] Real-time транскрипция
- [x] Стоп-слово "отмена"
- [x] Audio ducking (приглушение музыки)
- [x] История транскрипций
- [x] Унифицированное логирование (OSLog)
- [x] .app bundle сборка
- [x] Автоматическая вставка EarPods подсказки
- [x] Batch транскрипция файлов
- [x] Стерео диалоги с разделением спикеров
- [x] Voice Activity Detection (7+ алгоритмов)
- [x] Timeline View для визуализации диалогов
- [x] Автоматическое сжатие диалогов (удаление тишины)
- [x] Встроенный audio player
- [x] Пользовательские словари для улучшения распознавания
- [x] Показ в Dock при открытии окна транскрипции

### Запланировано 📋
- [ ] Code signing & notarization
- [ ] DMG installer
- [ ] Auto-update (Sparkle)
- [ ] Мультиязычный UI
- [ ] Homebrew Cask distribution
- [ ] Настройка чувствительности VAD
- [ ] Экспорт истории транскрипций

---

## 🤝 Вклад в проект

Приветствуются Pull Request'ы!

1. Fork репозитория
2. Создайте feature branch
3. Закоммитьте изменения
4. Push в branch
5. Создайте Pull Request

---

## 📄 Лицензия

MIT License - See LICENSE file for details

---

## 🙏 Благодарности

- **WhisperKit** by Argmax Inc. - Отличная реализация Whisper для Apple Silicon
- **OpenAI Whisper** - Передовое распознавание речи
- **Apple MLX** - ML фреймворк для Apple Silicon
- **Claude Code** - Помощь в разработке

---

## 📞 Поддержка

По вопросам и проблемам:
- Проверьте документацию в `CLAUDE.md`
- Просмотрите логи через `log stream`
- Протестируйте с индивидуальными тестовыми исполняемыми файлами
- Создайте Issue в GitHub

---

<div align="center">

**Создано с ❤️ используя Swift и WhisperKit**

🎤 Приятного голосового ввода! ✨

</div>
