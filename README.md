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
- ⌨️ **Настраиваемые горячие клавиши** - F1-F19, любая клавиша с модификатором (⌘/⌥/⌃)
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

**PushToTalk** построен на современных технологиях и паттернах проектирования:

### Технологический стек

| Компонент | Технология |
|-----------|------------|
| Язык | Swift 6.2 |
| Архитектура | Clean Architecture + MVVM + Coordinator |
| ML Framework | WhisperKit (MLX-based) |
| Аудио | AVFoundation |
| Горячие клавиши | CGEventTap API (Accessibility) |
| UI | SwiftUI + AppKit |
| DI | ServiceContainer (Protocol-based) |
| Локализация | EN/RU (расширяемо) |
| Тестирование | XCTest (32 unit tests, 100% pass rate) |
| Сборка | Swift Package Manager |

### Архитектурные принципы

- **Clean Architecture** - Четкое разделение на слои (Presentation, Domain, Data)
- **SOLID Principles** - Все компоненты следуют принципам SOLID
- **Protocol-Oriented** - Все сервисы определены через протоколы
- **Dependency Injection** - Централизованный ServiceContainer
- **MVVM Pattern** - ViewModels для всех UI компонентов
- **Coordinator Pattern** - Управление навигацией и бизнес-логикой
- **Async/Await** - Современный Swift Concurrency вместо callbacks

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

2. **Accessibility** - Требуется для мониторинга горячих клавиш и вставки текста
   - Системные настройки → Конфиденциальность и безопасность → Универсальный доступ
   - ✅ Включите **PushToTalk**

---

## 📖 Использование

### Интерфейс Menu Bar

Найдите иконку **🎤** в menu bar (правый верхний угол):

- **🎤** - Готов к записи
- **🎤 (filled)** - Идет запись
- **⚙️** - Идет обработка

**Нажмите на иконку** чтобы открыть настройки:
- Выбор модели Whisper (Tiny/Base/Small/Medium/Large)
- Выбор горячей клавиши (F-keys или комбинации с модификатором)
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
- **F1-F19** - Функциональные клавиши без модификаторов
- **Любая клавиша + ⌘/⌥/⌃** - Комбинации с модификатором (например, ⌥F или ⌃Space)

**Ограничения**: Обычные буквы/символы без модификатора запрещены (конфликт с текстовым вводом). Требуется Accessibility разрешение.

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
│   ├── App/                               # 🎯 Application Layer
│   │   ├── PushToTalkApp.swift           # @main точка входа
│   │   ├── AppDelegate.swift              # Жизненный цикл приложения
│   │   ├── AppCoordinator.swift          # Главный координатор приложения
│   │   └── ServiceContainer.swift         # DI контейнер (Protocol-based)
│   ├── Coordinators/                      # 🧭 Coordinators
│   │   ├── RecordingCoordinator.swift    # Координатор записи и транскрипции
│   │   └── SettingsCoordinator.swift     # Координатор настроек
│   ├── Presentation/                      # 🎨 Presentation Layer
│   │   ├── ViewModels/                   # MVVM ViewModels
│   │   │   └── SettingsViewModel.swift  # ViewModel для настроек
│   │   └── Views/                        # SwiftUI Views
│   │       ├── MenuBar/
│   │       │   └── MenuBarController.swift
│   │       ├── Settings/                 # Модульные Settings Views
│   │       │   ├── GeneralSettingsView.swift
│   │       │   ├── ModelSettingsView.swift
│   │       │   ├── HotkeySettingsView.swift
│   │       │   ├── VocabularySettingsView.swift
│   │       │   ├── AudioSettingsView.swift
│   │       │   ├── HistorySettingsView.swift
│   │       │   └── DebugSettingsView.swift
│   │       └── Components/               # Переиспользуемые UI компоненты
│   ├── Services/                          # 🔧 Services Layer
│   │   ├── Protocols/                    # Service Protocols
│   │   │   ├── AudioCaptureServiceProtocol.swift
│   │   │   ├── WhisperServiceProtocol.swift
│   │   │   ├── TextInserterProtocol.swift
│   │   │   └── VocabularyManagerProtocol.swift
│   │   └── Implementation/               # Service Implementations
│   │       ├── AudioCaptureService.swift
│   │       ├── WhisperService.swift
│   │       ├── KeyboardMonitor.swift
│   │       ├── TextInserter.swift
│   │       └── AlertService.swift
│   ├── Managers/                          # 📦 Managers
│   │   ├── Protocols/                    # Manager Protocols
│   │   │   ├── ModelManagerProtocol.swift
│   │   │   ├── HotkeyManagerProtocol.swift
│   │   │   └── AudioDeviceManagerProtocol.swift
│   │   └── Implementation/               # Manager Implementations
│   │       ├── ModelManager.swift
│   │       ├── HotkeyManager.swift
│   │       ├── AudioDeviceManager.swift
│   │       ├── PermissionManager.swift
│   │       └── NotificationManager.swift
│   └── Utils/                             # 🛠️ Utilities
│       ├── Constants/                    # Константы
│       │   ├── AppConstants.swift
│       │   ├── UIConstants.swift
│       │   └── Strings.swift            # Локализуемые строки
│       ├── Extensions/                   # Swift Extensions
│       │   ├── String+Extensions.swift
│       │   ├── Array+Extensions.swift
│       │   └── View+Extensions.swift
│       ├── Audio/                        # Audio утилиты
│       │   ├── SpectralVAD.swift
│       │   ├── AdaptiveVAD.swift
│       │   └── SilenceDetector.swift
│       ├── Media/                        # Media утилиты
│       │   ├── SoundManager.swift
│       │   ├── AudioDuckingManager.swift
│       │   ├── MediaRemoteManager.swift
│       │   └── AudioPlayerManager.swift
│       └── Helpers/                      # Хелперы
│           ├── LogManager.swift
│           ├── UserSettings.swift
│           ├── TranscriptionHistory.swift
│           └── VocabularyDictionaries.swift
├── Resources/                             # 📦 Resources
│   ├── Info.plist
│   ├── PushToTalk.entitlements
│   ├── AppIcon.icns
│   └── Localization/                     # 🌍 Локализация (EN/RU)
│       ├── en.lproj/Localizable.strings
│       └── ru.lproj/Localizable.strings
├── Tests/                                 # ✅ Unit Tests
│   └── PushToTalkTests/
│       ├── CoordinatorTests/             # Тесты координаторов
│       │   └── RecordingCoordinatorTests.swift (18 tests)
│       ├── ViewModelTests/               # Тесты ViewModels
│       │   └── SettingsViewModelTests.swift (14 tests)
│       └── Mocks/                        # Mock объекты
│           ├── MockWhisperService.swift
│           ├── MockAudioCaptureService.swift
│           ├── MockTextInserter.swift
│           ├── MockVocabularyManager.swift
│           └── MockModelManager.swift
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
# Unit тесты (32 теста, 100% pass rate)
swift test

# Запуск отдельных тестовых наборов
swift test --filter RecordingCoordinatorTests  # 18 тестов
swift test --filter SettingsViewModelTests     # 14 тестов

# Тест с выводом
swift test --verbose
```

### Метрики тестирования

- **Всего тестов**: 32
- **Success rate**: 100%
- **Coverage**: ~30% основных компонентов
- **Execution time**: ~1.5 секунды

**Структура тестов:**
- RecordingCoordinatorTests (18) - Тесты координатора записи
- SettingsViewModelTests (14) - Тесты ViewModel настроек
- 5 Mock классов для изоляции зависимостей

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

1. **Prepare Environment** - Приглушение системной музыки, повышение громкости микрофона
2. **Capture** - AVAudioEngine захватывает микрофон (нативный формат)
3. **Convert** - AVAudioConverter ресемплирует в 16000 Hz mono Float32
4. **Buffer** - Аудио сэмплы хранятся как Float32 массив
5. **Real-time** - Чанки по 2 секунды отправляются на транскрипцию
6. **Process** - WhisperKit обрабатывает финальный буфер
7. **Restore Environment** - Восстановление системной музыки и громкости микрофона ПОСЛЕ транскрипции

### Whisper Integration

- **Модели**: Tiny (~150 MB), Base (~300 MB), Small (~600 MB), Medium (~1.5 GB), Large (~3 GB)
- **Framework**: WhisperKit (MLX-based)
- **Устройство**: Apple Neural Engine + GPU (Metal)
- **Формат**: 16kHz mono Float32
- **Скорость**: ~5-10x реального времени на M1 Max
- **Multilingual**: Автоопределение языка (опционально)

### Мониторинг клавиатуры

**CGEventTap API** (единственный метод):
- Глобальный event tap через `CGEvent.tapCreate`
- Требует Accessibility разрешения
- Ограничен безопасными комбинациями: F-keys (F1-F19) без модификаторов или любая клавиша с модификатором (Cmd/Opt/Ctrl)
- Автоматическая переактивация при отключении системой
- События горячей клавиши поглощаются (не передаются в приложения)

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
- Восстанавливает громкость после завершения транскрипции (не после остановки записи!)
- Такой подход предотвращает попадание кусочков музыки в конец аудио буфера
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
2. Убедитесь, что Accessibility разрешение предоставлено (требуется для CGEventTap)
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
- [x] Мониторинг F16 (CGEventTap)
- [x] Вставка текста (Clipboard + Accessibility)
- [x] Menu bar UI (SwiftUI + AppKit)
- [x] Liquid Glass всплывающее окно
- [x] Звуковая обратная связь
- [x] Управление разрешениями
- [x] Настраиваемые горячие клавиши (F-keys, модификатор + клавиша)
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
