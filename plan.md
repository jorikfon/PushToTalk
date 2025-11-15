# План разделения проекта PushToTalk

## Цель
Разделить монолитный проект PushToTalk на два независимых приложения:
1. **PushToTalk** - легковесное приложение для быстрой диктовки с хоткеем
2. **TranscribeIt** - полноценное приложение для транскрибации длинных аудиофайлов

## Текущая ситуация

### Проблемы текущей архитектуры
- Смешивание двух разных use cases в одном приложении
- PushToTalk перегружен функционалом транскрибации файлов
- Сложная кодовая база с взаимозависимостями
- Невозможность независимого развития функционала

### Текущая структура проекта
```
PushToTalk/
├── Sources/
│   ├── App/
│   │   ├── PushToTalkApp.swift        # Главный entry point
│   │   └── AppDelegate.swift          # Координатор всех сервисов
│   ├── Services/
│   │   ├── AudioCaptureService.swift  # Запись аудио с микрофона
│   │   ├── WhisperService.swift       # WhisperKit интеграция
│   │   ├── KeyboardMonitor.swift      # Carbon API для хоткеев
│   │   ├── TextInserter.swift         # Вставка текста в курсор
│   │   ├── FileTranscriptionService.swift      # Транскрибация файлов
│   │   └── BatchTranscriptionService.swift     # Batch обработка
│   ├── UI/
│   │   ├── MenuBarController.swift            # Menu bar приложения
│   │   ├── FloatingRecordingWindow.swift      # Окно записи
│   │   ├── ModernSettingsView.swift           # Настройки
│   │   ├── FileTranscriptionWindow.swift      # Окно транскрибации файлов
│   │   └── HotkeyRecorderView.swift           # Настройка хоткеев
│   └── Utils/
│       ├── ModelManager.swift                 # Управление моделями Whisper
│       ├── LogManager.swift                   # Unified logging
│       ├── HotkeyManager.swift                # Менеджер хоткеев
│       ├── AudioPlayerManager.swift           # Аудио плеер для файлов
│       ├── AudioFileNormalizer.swift          # Нормализация аудио
│       ├── VocabularyManager.swift            # Словари
│       ├── VocabularyDictionaries.swift       # Хранение словарей
│       ├── MediaRemoteManager.swift           # Управление медиа-плеерами
│       ├── TranscriptionHistory.swift         # История транскрипций
│       ├── UserSettings.swift                 # Настройки пользователя
│       ├── SpectralVAD.swift                  # Voice Activity Detection
│       ├── AdaptiveVAD.swift                  # Адаптивный VAD
│       ├── VoiceActivityDetector.swift        # VAD детектор
│       ├── SilenceDetector.swift              # Детектор тишины
│       ├── AudioNormalizer.swift              # Нормализация аудио
│       ├── SoundManager.swift                 # Звуковые уведомления
│       ├── NotificationManager.swift          # Системные уведомления
│       ├── AudioFeedbackManager.swift         # Аудио обратная связь
│       ├── AudioDeviceManager.swift           # Управление аудио устройствами
│       ├── MicrophoneVolumeManager.swift      # Управление громкостью микрофона
│       └── PermissionManager.swift            # Проверка разрешений
└── Package.swift
```

## Целевая архитектура

### TranscribeIt - Новое приложение
**Путь**: `~/Developement/TranscribeIt`
**Назначение**: Детальная транскрибация аудиофайлов с редактированием и экспортом

#### Структура проекта
```
TranscribeIt/
├── Sources/
│   ├── App/
│   │   ├── TranscribeItApp.swift      # Entry point
│   │   └── AppDelegate.swift          # Менеджер приложения
│   ├── Services/
│   │   ├── WhisperService.swift       # Копия из PushToTalk
│   │   ├── FileTranscriptionService.swift     # Перенос
│   │   └── BatchTranscriptionService.swift    # Перенос
│   ├── UI/
│   │   ├── MainWindow.swift           # Главное окно (переименованная FileTranscriptionWindow)
│   │   ├── MenuBarController.swift    # Минимальный menu bar
│   │   └── SettingsView.swift         # Настройки транскрибации
│   └── Utils/
│       ├── ModelManager.swift         # Копия из PushToTalk
│       ├── LogManager.swift           # Копия из PushToTalk
│       ├── AudioPlayerManager.swift   # Перенос
│       ├── AudioFileNormalizer.swift  # Перенос
│       ├── VocabularyManager.swift    # Перенос
│       ├── VocabularyDictionaries.swift  # Перенос
│       ├── UserSettings.swift         # Копия с настройками для TranscribeIt
│       ├── ExportManager.swift        # НОВЫЙ: экспорт в форматы
│       └── PermissionManager.swift    # Копия (только микрофон)
├── Resources/
│   └── Assets.xcassets/
├── Package.swift
└── build_app.sh
```

#### Основной функционал TranscribeIt
1. **Drag & Drop интерфейс**: Перетаскивание аудиофайлов для транскрибации
2. **Batch обработка**: Очередь файлов с прогресс-баром
3. **Dual-channel режим**: Раздельная транскрибация левого/правого каналов (диалоги)
4. **Аудио-плеер**:
   - Воспроизведение оригинала
   - Синхронизация с текстом
   - Кликабельные таймкоды
5. **Редактирование текста**:
   - Inline редактирование сегментов
   - Сохранение таймкодов
   - Применение словарей
6. **Экспорт в форматы**:
   - SRT (субтитры)
   - VTT (WebVTT)
   - TXT (простой текст)
   - DOCX (Word документ)
   - JSON (с метаданными и таймкодами)
7. **Настройки**:
   - Выбор модели Whisper
   - VAD параметры
   - Словари и автокоррекция
   - Форматы экспорта по умолчанию

#### Технические детали TranscribeIt
- **UI Framework**: SwiftUI (текущий дизайн с колонками)
- **Speech Recognition**: WhisperKit 0.9.0+
- **Audio Processing**: AVFoundation
- **Минимальная версия**: macOS 14+
- **Архитектура**: Menu bar приложение (может показываться в Dock при открытии окна)

### PushToTalk - Упрощённое приложение
**Путь**: `~/Developement/PushToTalk` (текущий проект)
**Назначение**: Мгновенная диктовка с автоматической вставкой текста

#### Что удаляется
```
Sources/
├── Services/
│   ├── FileTranscriptionService.swift      # УДАЛИТЬ
│   └── BatchTranscriptionService.swift     # УДАЛИТЬ
├── UI/
│   └── FileTranscriptionWindow.swift       # УДАЛИТЬ
└── Utils/
    ├── AudioPlayerManager.swift            # УДАЛИТЬ
    ├── AudioFileNormalizer.swift           # УДАЛИТЬ
    └── VocabularyDictionaries.swift        # УДАЛИТЬ (если не используется)
```

#### Что остаётся
```
Sources/
├── App/
│   ├── PushToTalkApp.swift          # Упростить
│   └── AppDelegate.swift            # Убрать ссылки на FileTranscriptionService
├── Services/
│   ├── AudioCaptureService.swift    # Оставить
│   ├── WhisperService.swift         # Оставить
│   ├── KeyboardMonitor.swift        # Оставить
│   └── TextInserter.swift           # Оставить
├── UI/
│   ├── MenuBarController.swift      # Упростить меню
│   ├── FloatingRecordingWindow.swift  # Оставить
│   ├── ModernSettingsView.swift     # Упростить настройки
│   └── HotkeyRecorderView.swift     # Оставить
└── Utils/
    ├── ModelManager.swift           # Оставить
    ├── LogManager.swift             # Оставить
    ├── HotkeyManager.swift          # Оставить
    ├── VocabularyManager.swift      # Оставить (для качества распознавания)
    ├── MediaRemoteManager.swift     # Оставить (YouTube Music, Spotify)
    ├── TranscriptionHistory.swift   # Оставить (история в памяти)
    ├── UserSettings.swift           # Упростить
    ├── SpectralVAD.swift           # Оставить
    ├── AdaptiveVAD.swift           # Оставить
    ├── VoiceActivityDetector.swift  # Оставить
    ├── SilenceDetector.swift        # Оставить
    ├── AudioNormalizer.swift        # Оставить
    ├── SoundManager.swift           # Оставить
    ├── NotificationManager.swift    # Оставить
    ├── AudioFeedbackManager.swift   # Оставить
    ├── AudioDeviceManager.swift     # Оставить
    ├── MicrophoneVolumeManager.swift  # Оставить
    └── PermissionManager.swift      # Оставить
```

#### Упрощённый функционал PushToTalk
1. **Push-to-Talk диктовка**:
   - Хоткей (по умолчанию F16)
   - Floating окно с визуализацией
   - Автоматическая вставка текста в курсор
   - Real-time транскрипция (опционально)

2. **История транскрипций**:
   - Хранение последних 50 транскрипций в памяти
   - Быстрый доступ через menu bar
   - Копирование в буфер обмена
   - БЕЗ сохранения на диск

3. **Управление медиа-плеерами**:
   - Автопауза YouTube Music при записи
   - Автопауза Spotify при записи
   - Автовозобновление после транскрипции

4. **Минимальные настройки**:
   - Выбор модели Whisper (tiny/base/small)
   - Настройка хоткея
   - Выбор микрофона
   - Включение/выключение real-time транскрипции
   - Словари для повышения качества

5. **Словари и автокоррекция**:
   - Использование VocabularyManager
   - Настройка терминов и аббревиатур
   - Применение при транскрибации

#### Упрощения в UI
- **MenuBarController**: Убрать пункт "Transcribe Files..."
- **ModernSettingsView**: Убрать вкладки транскрибации файлов
- **AppDelegate**: Удалить `fileTranscriptionService` и связанные методы

## Технические детали разделения

### Зависимости Package.swift

#### TranscribeIt/Package.swift
```swift
// Новый независимый проект
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
]

targets: [
    .executableTarget(
        name: "TranscribeIt",
        dependencies: ["WhisperKit"]
    )
]
```

#### PushToTalk/Package.swift (обновлённый)
```swift
// Упрощённый проект
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    .package(url: "https://github.com/PrivateFrameworks/MediaRemote.git", from: "0.1.0")
]

targets: [
    .executableTarget(
        name: "PushToTalkSwift",
        dependencies: [
            "WhisperKit",
            .product(name: "PrivateMediaRemote", package: "MediaRemote")
        ]
    )
]
```

### Копируемые компоненты (независимые копии)

Следующие файлы будут скопированы в оба проекта и могут независимо развиваться:

1. **WhisperService.swift**
   - PushToTalk: оптимизация для коротких записей
   - TranscribeIt: оптимизация для длинных файлов

2. **ModelManager.swift**
   - PushToTalk: управление маленькими моделями (tiny/base/small)
   - TranscribeIt: поддержка всех моделей включая large

3. **LogManager.swift**
   - PushToTalk: subsystem "com.pushtotalk.app"
   - TranscribeIt: subsystem "com.transcribeit.app"

4. **UserSettings.swift**
   - PushToTalk: настройки хоткея, микрофона, модели
   - TranscribeIt: настройки экспорта, VAD, словарей

5. **VocabularyManager.swift**
   - Общая логика, но независимые хранилища UserDefaults

### Миграция данных пользователя

#### UserDefaults разделение
- **PushToTalk**: `com.pushtotalk.settings.*`
  - Хоткей
  - Выбранная модель
  - Выбранный микрофон
  - История транскрипций (в памяти)
  - Словари

- **TranscribeIt**: `com.transcribeit.settings.*`
  - Выбранная модель
  - VAD параметры
  - Словари
  - Форматы экспорта по умолчанию

#### Модели WhisperKit
- Общее хранилище: `~/Library/Caches/whisperkit_models/`
- Модели используются обоими приложениями
- Не требуется дублирование

### Новый функционал для TranscribeIt

#### ExportManager.swift
Новый компонент для экспорта в различные форматы:

**Функции**:
1. `exportToSRT()` - Экспорт в формат SubRip (.srt)
2. `exportToVTT()` - Экспорт в WebVTT (.vtt)
3. `exportToTXT()` - Простой текст без таймкодов
4. `exportToDOCX()` - Word документ с форматированием
5. `exportToJSON()` - JSON с полными метаданными

**Метаданные для экспорта**:
- Имя файла
- Дата транскрибации
- Модель Whisper
- Длительность аудио
- Язык
- Таймкоды сегментов
- Спикеры (для dual-channel)

#### Улучшения UI для TranscribeIt

**MainWindow.swift** (переименованная FileTranscriptionWindow):
- Добавить кнопки экспорта
- Улучшить редактирование текста
- Добавить поиск по транскрипции
- Показывать метаданные файла

**SettingsView.swift**:
- Настройки экспорта
- Управление словарями
- VAD параметры
- Качество транскрибации

### Упрощения для PushToTalk

#### AppDelegate.swift изменения
**Удалить**:
- `fileTranscriptionService: FileTranscriptionService?`
- `fileTranscriptionWindows: [FileTranscriptionWindow]`
- Методы `showInDock()` и `hideFromDockIfNoWindows()`
- Обработчики открытия файлов

**Упростить**:
- Всегда `.accessory` режим (никогда не показывать в Dock)
- Убрать переключение activation policy

#### MenuBarController.swift изменения
**Удалить пункты меню**:
- "Transcribe Files..."
- "Open Transcription Window"

**Оставить пункты меню**:
- "Start Recording" / "Stop Recording"
- "Settings"
- "Transcription History" (подменю с последними транскрипциями)
- "About"
- "Quit"

#### ModernSettingsView.swift изменения
**Удалить вкладки**:
- File Transcription
- Batch Processing
- Export Settings

**Оставить вкладки**:
- General (хоткей, микрофон)
- Whisper Model (выбор модели)
- Advanced (VAD, real-time, словари)
- About

## Этапы выполнения

### Этап 1: Подготовка инфраструктуры
1. Создать структуру директорий TranscribeIt
2. Создать базовый Package.swift для обоих проектов
3. Создать .gitignore для TranscribeIt
4. Создать build_app.sh для TranscribeIt

### Этап 2: Копирование общих компонентов
1. Скопировать WhisperService.swift в оба проекта
2. Скопировать ModelManager.swift в оба проекта
3. Скопировать LogManager.swift в оба проекта (изменить subsystem)
4. Скопировать UserSettings.swift в оба проекта
5. Скопировать PermissionManager.swift в оба проекта

### Этап 3: Перенос компонентов в TranscribeIt
1. Переместить FileTranscriptionService.swift → TranscribeIt/Services/
2. Переместить BatchTranscriptionService.swift → TranscribeIt/Services/
3. Переместить FileTranscriptionWindow.swift → TranscribeIt/UI/MainWindow.swift
4. Переместить AudioPlayerManager.swift → TranscribeIt/Utils/
5. Переместить AudioFileNormalizer.swift → TranscribeIt/Utils/
6. Переместить VocabularyManager.swift в оба проекта
7. Переместить VocabularyDictionaries.swift → TranscribeIt/Utils/

### Этап 4: Создание TranscribeIt приложения
1. Создать TranscribeItApp.swift (entry point)
2. Создать AppDelegate.swift для TranscribeIt
3. Создать минимальный MenuBarController.swift
4. Создать SettingsView.swift
5. Создать ExportManager.swift
6. Настроить импорты и зависимости

### Этап 5: Упрощение PushToTalk
1. Удалить FileTranscriptionService.swift
2. Удалить BatchTranscriptionService.swift
3. Удалить FileTranscriptionWindow.swift
4. Удалить AudioPlayerManager.swift (если не используется)
5. Удалить AudioFileNormalizer.swift
6. Обновить AppDelegate.swift (убрать ссылки на удалённые сервисы)
7. Обновить MenuBarController.swift (убрать пункты меню)
8. Упростить ModernSettingsView.swift (убрать вкладки)
9. Обновить Package.swift

### Этап 6: Тестирование и отладка
1. Собрать TranscribeIt и проверить базовый функционал
2. Собрать PushToTalk и проверить упрощённый функционал
3. Протестировать транскрибацию файлов в TranscribeIt
4. Протестировать Push-to-Talk в PushToTalk
5. Проверить, что модели WhisperKit используются совместно
6. Проверить, что настройки не конфликтуют

### Этап 7: Документация
1. Обновить CLAUDE.md для PushToTalk
2. Создать CLAUDE.md для TranscribeIt
3. Обновить README.md для обоих проектов
4. Задокументировать процесс сборки

## Риски и ограничения

### Потенциальные проблемы
1. **Дублирование кода**: Общие компоненты будут копироваться
   - Решение: Это осознанный выбор для независимого развития

2. **Размер приложений**: Оба приложения будут содержать WhisperKit
   - Решение: Модели кешируются в общей директории

3. **Синхронизация словарей**: Словари не будут синхронизироваться между приложениями
   - Решение: Каждое приложение имеет свои словари

4. **Миграция пользователей**: Пользователи текущей версии потеряют доступ к транскрибации файлов в PushToTalk
   - Решение: Показать уведомление о TranscribeIt при первом запуске

### Ограничения
1. Независимые копии кода требуют дублирования исправлений багов
2. Нет возможности переключаться между приложениями через menu bar
3. Каждое приложение занимает место в menu bar отдельно

## Преимущества разделения

### Для PushToTalk
- Минимальный размер приложения
- Быстрый запуск
- Простой и понятный UI
- Фокус на основной задаче - быстрая диктовка

### Для TranscribeIt
- Полноценный инструмент для работы с аудио
- Независимое развитие функционала экспорта
- Возможность добавления новых форматов
- Профессиональный UI для работы с транскрипциями

### Для разработки
- Чистое разделение ответственности
- Независимое развитие проектов
- Упрощение кодовой базы каждого приложения
- Возможность переиспользования компонентов

## Дальнейшее развитие

### PushToTalk roadmap
- Поддержка множественных хоткеев
- Голосовые команды
- Интеграция с AI ассистентами
- Поддержка плагинов для кастомной обработки текста

### TranscribeIt roadmap
- Поддержка видео файлов (извлечение аудио)
- Распознавание спикеров (diarization)
- Перевод на другие языки
- Интеграция с облачными хранилищами
- Collaborative редактирование
- Экспорт в форматы Final Cut Pro / Premiere Pro

## Заключение

Разделение проекта на PushToTalk и TranscribeIt позволит:
1. Упростить каждое приложение
2. Улучшить пользовательский опыт
3. Ускорить разработку новых функций
4. Сохранить чистоту кодовой базы

Независимые копии общих компонентов обеспечат гибкость для будущих изменений без риска сломать второе приложение.
