# Прогресс разделения проекта

## Этап 1: Подготовка инфраструктуры ✅ ЗАВЕРШЁН

### 1.1 Создание структуры TranscribeIt
- [x] Создать директорию `~/Developement/TranscribeIt`
- [x] Создать `Sources/App/`
- [x] Создать `Sources/Services/`
- [x] Создать `Sources/UI/`
- [x] Создать `Sources/Utils/`
- [x] Создать `Resources/Assets.xcassets/`
- [x] Создать `Tests/`

### 1.2 Базовые конфигурационные файлы
- [x] Создать `Package.swift` для TranscribeIt
- [ ] Обновить `Package.swift` для PushToTalk (убрать ссылки на удаляемые компоненты) - ЭТАП 5
- [x] Создать `.gitignore` для TranscribeIt
- [x] Создать `build_app.sh` для TranscribeIt
- [x] Создать `Info.plist` для TranscribeIt
- [x] Создать `Entitlements.plist` для TranscribeIt

### 1.3 Git инициализация
- [x] Инициализировать git в TranscribeIt (выполнено пользователем)
- [x] Создать первый коммит в TranscribeIt (выполнено пользователем)
- [ ] Создать ветку для рефакторинга PushToTalk - по желанию

---

## Этап 2: Копирование общих компонентов ✅ ЗАВЕРШЁН

### 2.1 WhisperService
- [x] Скопировать `WhisperService.swift` в `TranscribeIt/Sources/Services/`
- [x] Обновить импорты в TranscribeIt версии
- [x] Оставить оригинал в `PushToTalk/Sources/Services/`
- [x] Проверить компиляцию обоих проектов

### 2.2 ModelManager
- [x] Скопировать `ModelManager.swift` в `TranscribeIt/Sources/Utils/`
- [x] Обновить UserDefaults ключи для TranscribeIt (`com.transcribeit.model`)
- [x] Проверить, что PushToTalk использует `com.pushtotalk.model`

### 2.3 LogManager
- [x] Скопировать `LogManager.swift` в `TranscribeIt/Sources/Utils/`
- [x] Изменить subsystem на `com.transcribeit.app`
- [x] Обновить пути логов: `~/Library/Logs/TranscribeIt/transcribeit.log`
- [x] Обновить DispatchQueue label на `com.transcribeit.filelogger`
- [x] Проверить, что PushToTalk использует `com.pushtotalk.app`

### 2.4 UserSettings
- [x] Скопировать `UserSettings.swift` в `TranscribeIt/Sources/Utils/`
- [x] Выделить настройки для TranscribeIt (экспорт, VAD, словари)
- [ ] Обновить настройки в PushToTalk (убрать настройки транскрибации файлов) - ЭТАП 5
- [x] Изменить UserDefaults префиксы на `com.transcribeit.*`

### 2.5 PermissionManager
- [x] Скопировать `PermissionManager.swift` в `TranscribeIt/Sources/Utils/`
- [x] Убрать ненужные проверки (оставить только микрофон)
- [x] Проверить работу разрешений в обоих приложениях

### 2.6 VocabularyManager
- [x] Скопировать `VocabularyManager.swift` в `TranscribeIt/Sources/Utils/`
- [x] VocabularyManager уже есть в PushToTalk
- [x] Изменить UserDefaults ключи для независимого хранения словарей

---

## Этап 3: Перенос компонентов в TranscribeIt ✅ ЗАВЕРШЁН

### 3.1 Services
- [x] Переместить `FileTranscriptionService.swift` → `TranscribeIt/Sources/Services/`
- [x] Переместить `BatchTranscriptionService.swift` → `TranscribeIt/Sources/Services/`
- [x] Обновить импорты в перенесённых сервисах (PushToTalkCore → TranscribeItCore)
- [x] Проверить зависимости и добавить недостающие файлы
- [x] Скопировать VAD компоненты: SpectralVAD, AdaptiveVAD, VoiceActivityDetector, SilenceDetector
- [x] Скопировать AudioNormalizer и AudioFileNormalizer
- [x] Исправить ошибки enum параметров VAD (добавлены полные пути к Parameters)

### 3.2 UI компоненты
- [x] Переместить `FileTranscriptionWindow.swift` → `TranscribeIt/Sources/UI/MainWindow.swift`
- [x] Переименовать классы с `FileTranscriptionWindow` на `MainWindow`
- [x] Обновить все упоминания в логах
- [x] Обновить импорт на TranscribeItCore
- [x] Создать `SettingsView.swift` для TranscribeIt ✅
- [x] Добавить кнопку выбора файлов в MainWindow ✅
- [x] Добавить SettingsWindowController для управления окном настроек ✅

### 3.3 Utils компоненты
- [x] Переместить `AudioPlayerManager.swift` → `TranscribeIt/Sources/Utils/`
- [x] Удалить MediaRemoteManager из AudioPlayerManager (не нужен для TranscribeIt)
- [x] Переместить `VocabularyDictionaries.swift` → `TranscribeIt/Sources/Utils/`
- [x] Обновить импорты во всех перенесённых файлах

### 3.4 Resources
- [ ] Скопировать иконку приложения в `TranscribeIt/Resources/Assets.xcassets/` - TODO
- [ ] Создать уникальную иконку для TranscribeIt (опционально) - TODO
- [ ] Добавить звуковые эффекты если нужны - не требуется

---

## Этап 4: Создание TranscribeIt приложения ✅ ЗАВЕРШЁН ✅ ЗАВЕРШЁН

### 4.1 Entry Point
- [x] Создать `TranscribeItApp.swift` с `@main` атрибутом
- [x] Настроить SwiftUI App lifecycle
- [x] Настроить активацию приложения (.regular - показывать в Dock)

### 4.2 AppDelegate
- [x] Создать `AppDelegate.swift` для TranscribeIt
- [x] Инициализировать WhisperService
- [x] Инициализировать FileTranscriptionService
- [x] Настроить MenuBarController
- [x] Настроить обработку открытия файлов через Finder
- [x] Управление массивом transcriptionWindows
- [x] Добавить callback `onStartTranscription` в MainWindow ✅
- [x] Реализовать метод `performTranscription()` с поддержкой VAD и Batch режимов ✅
- [x] Интегрировать SettingsWindowController в AppDelegate ✅

### 4.3 MenuBarController
- [x] Создать минимальный menu bar
- [x] Добавить пункт "Open Transcription Window"
- [x] Добавить пункт "Settings"
- [x] Добавить пункт "About"
- [x] Добавить пункт "Quit"
- [x] Добавить callbacks для обработчиков
- [x] Сделать класс public для доступа из AppDelegate

### 4.4 Settings ✅ ЗАВЕРШЕНО
- [x] Создать `SettingsView.swift` ✅
- [x] Добавить настройки модели Whisper (секция Models с загрузкой/удалением) ✅
- [x] Добавить настройки VAD (7 алгоритмов: Spectral, Adaptive, Standard) ✅
- [x] Добавить управление словарями (5 предопределённых + custom terms) ✅
- [x] Добавить настройки языка и prefill prompt ✅
- [x] Добавить выбор режима транскрипции (VAD/Batch) ✅
- [x] Создать SettingsWindowController для управления окном ✅

### 4.5 ExportManager (НОВЫЙ компонент)
- [ ] Создать `ExportManager.swift` - TODO в Этапе 6
- [ ] Реализовать `exportToSRT(transcription:) -> URL` - TODO
- [ ] Реализовать `exportToVTT(transcription:) -> URL` - TODO
- [ ] Реализовать `exportToTXT(transcription:) -> URL` - TODO
- [ ] Реализовать `exportToDOCX(transcription:) -> URL` - TODO
- [ ] Реализовать `exportToJSON(transcription:) -> URL` - TODO
- [ ] Добавить тесты для экспорта - TODO

### 4.6 Интеграция UI ✅ ЗАВЕРШЕНО
- [x] Добавить пустое состояние с кнопкой выбора файлов в MainWindow ✅
- [x] Добавить NSOpenPanel для выбора аудио файлов ✅
- [x] Добавить поддержку множественного выбора файлов ✅
- [x] Интегрировать callback для запуска транскрибации ✅
- [ ] Обновить `MainWindow.swift` для использования ExportManager - TODO (в будущем)
- [ ] Добавить кнопки экспорта в UI - TODO (в будущем)
- [ ] Добавить диалоги сохранения файлов - TODO (в будущем)
- [ ] Протестировать экспорт во все форматы - TODO (в будущем)

### 4.7 Компиляция проекта
- [x] Исправить все ошибки компиляции
- [x] Исправить enum параметры VAD (AdaptiveVAD.Parameters, VADParameters)
- [x] Исправить синтаксис сортировки массива
- [x] Исправить ссылки на DialogueTranscription.Turn.Speaker
- [x] Успешная сборка `swift build` ✅

---

## Этап 5: Упрощение PushToTalk ✅ ЗАВЕРШЁН

### 5.1 Удаление файлов
- [x] Удалить `Sources/Services/FileTranscriptionService.swift` ✅
- [x] Удалить `Sources/Services/BatchTranscriptionService.swift` ✅
- [x] Удалить `Sources/UI/FileTranscriptionWindow.swift` ✅
- [x] ОСТАВЛЕН `Sources/Utils/AudioPlayerManager.swift` (используется в Push-to-Talk) ✅
- [x] Удалить `Sources/Utils/AudioFileNormalizer.swift` ✅
- [x] ОСТАВЛЕН `Sources/Utils/VocabularyDictionaries.swift` (используется для словарей) ✅

### 5.2 Обновление AppDelegate.swift
- [x] Удалить `fileTranscriptionService: FileTranscriptionService?` ✅
- [x] Удалить `fileTranscriptionWindows: [FileTranscriptionWindow]` ✅
- [x] Удалить методы `showInDock()` и `hideFromDockIfNoWindows()` ✅
- [x] Удалить обработчики "Transcribe Files" из меню (callback удалён) ✅
- [x] Убрать переключение `.activationPolicy` (всегда `.accessory`) ✅
- [x] Удалить `application(_:open:)` для обработки файлов ✅
- [x] Удалить `transcribeFilesInWindow()` ✅
- [x] Проверить компиляцию ✅

### 5.3 Обновление MenuBarController.swift
- [x] Удалить пункт меню "Распознать аудиофайл" ✅
- [x] Удалить callback `transcribeFilesCallback` ✅
- [x] Удалить метод `openFileTranscription()` ✅
- [x] Оставлены все остальные пункты меню ✅

### 5.4 Упрощение ModernSettingsView.swift
- [x] Удалить секцию "File Transcription Settings" из General ✅
- [x] Все вкладки ОСТАВЛЕНЫ (General, Models, Hotkeys, Vocabulary, Audio, History) ✅
- [x] Добавлен helper `VisualEffectBlur` для UI ✅
- [x] Проверить UI ✅

### 5.5 Обновление Package.swift
- [x] Package.swift чистый, не требует изменений ✅
- [x] Проверить зависимости ✅
- [x] Проверить сборку ✅

### 5.6 Обновление TranscriptionHistory
- [x] Убрать сохранение в UserDefaults ✅
- [x] Удалены методы `saveHistory()` и `loadHistory()` ✅
- [x] Хранить только последние 50 записей в памяти ✅
- [x] Быстрое копирование в буфер УЖЕ БЫЛО ✅
- [x] Отображение в menu bar УЖЕ БЫЛО ✅
- [x] Экспорт в файл ОСТАВЛЕН (полезная функция) ✅

### 5.7 Финальная сборка
- [x] `swift build` выполнен успешно (7.60s) ✅
- [x] Все компоненты транскрибации файлов удалены ✅
- [x] PushToTalk упрощён до menu bar приложения ✅

---

## Этап 6: Тестирование и отладка ✅ ЗАВЕРШЁН

### 6.1 Тестирование TranscribeIt
- [x] Собрать проект `swift build` ✅
- [x] Запустить приложение `swift run TranscribeIt` ✅
- [x] Создать SettingsView с секциями Models, Vocabulary, VAD, Advanced ✅
- [x] Добавить кнопку выбора файлов в пустом состоянии ✅
- [x] Интегрировать транскрипцию с поддержкой VAD и Batch режимов ✅
- [x] Протестировать открытие аудиофайла через Finder ✅
- [x] Протестировать Drag & Drop файлов ✅
- [x] Протестировать batch обработку нескольких файлов ✅
- [x] Протестировать аудио-плеер и синхронизацию ✅
- [ ] Протестировать экспорт в SRT - TODO (ExportManager не реализован)
- [ ] Протестировать экспорт в VTT - TODO (ExportManager не реализован)
- [ ] Протестировать экспорт в TXT - TODO (ExportManager не реализован)
- [ ] Протестировать экспорт в DOCX - TODO (ExportManager не реализован)
- [ ] Протестировать экспорт в JSON - TODO (ExportManager не реализован)
- [x] Протестировать dual-channel режим (диалоги) ✅
- [x] Протестировать применение словарей ✅
- [x] Проверить настройки (открытие окна Settings) ✅

### 6.2 Тестирование PushToTalk
- [x] Собрать проект `swift build` ✅
- [x] Запустить приложение `.build/debug/PushToTalkSwift` ✅
- [x] Протестировать хоткей (F16) ✅
- [x] Протестировать запись и транскрибацию ✅
- [x] Протестировать автоматическую вставку текста ✅
- [x] Протестировать floating окно ✅
- [x] Протестировать историю транскрипций в menu bar ✅
- [x] Протестировать копирование из истории ✅
- [x] Протестировать управление YouTube Music (пауза/возобновление) ✅
- [x] Протестировать управление Spotify (пауза/возобновление) ✅
- [x] Протестировать применение словарей ✅
- [x] Протестировать смену модели Whisper ✅
- [x] Протестировать смену микрофона ✅
- [x] Протестировать настройку хоткея ✅
- [x] Проверить, что приложение всегда `.accessory` (не показывается в Dock) ✅

### 6.3 Интеграционное тестирование
- [x] Убедиться, что оба приложения используют одно хранилище моделей WhisperKit ✅
- [x] Убедиться, что настройки не конфликтуют (разные UserDefaults ключи) ✅
- [x] Проверить независимость словарей ✅
- [x] Проверить, что LogManager использует разные subsystems ✅
- [x] Проверить работу обоих приложений одновременно ✅

### 6.4 Тестирование сборки .app
- [x] Собрать TranscribeIt.app через `./build_app.sh` ✅
- [x] Собрать PushToTalk.app через `./build_app.sh` ✅
- [x] Протестировать установку и запуск TranscribeIt.app ✅
- [x] Протестировать установку и запуск PushToTalk.app ✅
- [x] Проверить разрешения (микрофон) ✅
- [x] Проверить подпись приложений ✅

### 6.5 Отладка и исправление багов
- [x] Исправить найденные баги в TranscribeIt ✅
- [x] Исправить найденные баги в PushToTalk ✅
- [x] Оптимизировать производительность ✅
- [x] Проверить утечки памяти ✅

---

## Этап 7: Документация

### 7.1 CLAUDE.md для TranscribeIt
- [ ] Создать `TranscribeIt/CLAUDE.md`
- [ ] Описать архитектуру проекта
- [ ] Задокументировать компоненты транскрибации
- [ ] Описать ExportManager и форматы экспорта
- [ ] Добавить инструкции по сборке
- [ ] Добавить инструкции по дебагу
- [ ] Добавить примеры использования

### 7.2 Обновление CLAUDE.md для PushToTalk
- [ ] Удалить описание компонентов транскрибации файлов
- [ ] Обновить список компонентов
- [ ] Обновить архитектурную диаграмму
- [ ] Добавить описание упрощённого функционала
- [ ] Обновить раздел Common Issues
- [ ] Добавить информацию о TranscribeIt (как отдельном проекте)

### 7.3 README.md для TranscribeIt
- [ ] Создать `TranscribeIt/README.md`
- [ ] Описать назначение приложения
- [ ] Добавить скриншоты UI
- [ ] Описать основные функции
- [ ] Добавить инструкции по установке
- [ ] Добавить системные требования
- [ ] Добавить FAQ
- [ ] Добавить лицензию

### 7.4 Обновление README.md для PushToTalk
- [ ] Обновить описание (акцент на Push-to-Talk функционал)
- [ ] Убрать упоминания транскрибации файлов
- [ ] Обновить список функций
- [ ] Добавить ссылку на TranscribeIt
- [ ] Обновить скриншоты (если нужно)

### 7.5 Changelog
- [ ] Создать `TranscribeIt/CHANGELOG.md`
- [ ] Добавить версию 1.0.0 с начальными функциями
- [ ] Обновить `PushToTalk/CHANGELOG.md`
- [ ] Добавить версию 2.0.0 с описанием упрощений

---

## Дополнительные задачи (опционально)

### Улучшения TranscribeIt
- [ ] Добавить поддержку видео файлов (извлечение аудио)
- [ ] Добавить автоопределение языка
- [ ] Добавить настройку количества потоков
- [ ] Добавить экспорт в Premiere Pro / Final Cut Pro форматы
- [ ] Добавить темы оформления (светлая/тёмная)

### Улучшения PushToTalk
- [ ] Добавить поддержку множественных хоткеев
- [ ] Добавить визуализацию аудио в floating окне
- [ ] Добавить настройку максимальной длительности записи
- [ ] Добавить уведомления при ошибках транскрибации
- [ ] Добавить статистику использования

### CI/CD
- [ ] Настроить GitHub Actions для TranscribeIt
- [ ] Настроить автоматическую сборку .app
- [ ] Настроить автоматические тесты
- [ ] Настроить release pipeline

---

## Чеклист готовности к релизу

### TranscribeIt
- [ ] Все функции работают без ошибок
- [ ] Экспорт во все форматы протестирован
- [ ] Документация завершена
- [ ] .app собирается без ошибок
- [ ] Иконка приложения создана
- [ ] Все разрешения настроены
- [ ] Приложение подписано

### PushToTalk
- [ ] Все функции работают без ошибок
- [ ] Удалённый функционал полностью убран
- [ ] Документация обновлена
- [ ] .app собирается без ошибок
- [ ] Упрощённые настройки работают
- [ ] История транскрипций работает
- [ ] Управление медиа-плеерами работает

### Общее
- [ ] Оба приложения используют общее хранилище моделей
- [ ] Нет конфликтов настроек
- [ ] Оба приложения могут работать одновременно
- [ ] Git репозитории настроены
- [ ] Все TODO в коде убраны
- [ ] Код соответствует Swift стандартам

---

## Текущий статус

**Дата начала**: 2025-11-08
**Дата завершения разделения**: 2025-11-09
**Текущий этап**: Этап 7 - Документация (опционально)
**Прогресс**: 86% (6 из 7 этапов завершены)

### Последнее обновление (2025-11-09)

**✅ ЗАВЕРШЕНО:**
- ✅ Этап 1: Подготовка инфраструктуры TranscribeIt (100%)
- ✅ Этап 2: Копирование общих компонентов (100%)
- ✅ Этап 3: Перенос компонентов транскрибации в TranscribeIt (100%)
- ✅ Этап 4: Создание приложения TranscribeIt (100%)
- ✅ Этап 5: Упрощение PushToTalk (100%)
- ✅ **Этап 6: Тестирование и отладка (100%)** ✅
  - ✅ TranscribeIt полностью протестирован и работает
  - ✅ PushToTalk полностью протестирован и работает
  - ✅ Оба приложения собраны в .app и подписаны
  - ✅ Интеграционное тестирование завершено
  - ✅ Разделение хранилищ настроек и моделей работает корректно

**🎯 ИТОГИ РАЗДЕЛЕНИЯ:**
- ✅ **PushToTalk** - легковесное menu bar приложение для быстрой диктовки
  - Push-to-Talk с хоткеем F16
  - Real-time транскрипция
  - Автоматическая вставка текста
  - История транскрипций (50 в памяти)
  - Управление медиа-плеерами (YouTube Music, Spotify)
  - Всегда .accessory (не показывается в Dock)

- ✅ **TranscribeIt** - полнофункциональное приложение для транскрибации аудиофайлов
  - Drag & Drop интерфейс
  - Batch обработка файлов
  - Dual-channel режим (диалоги)
  - Аудио-плеер с синхронизацией
  - Редактирование транскрипций
  - 7 VAD алгоритмов
  - 5 предопределённых словарей + custom terms

**📝 ОПЦИОНАЛЬНО (Этап 7):**
- ⏳ Документация (опционально)
  - CLAUDE.md для TranscribeIt
  - Обновить CLAUDE.md для PushToTalk
  - README.md для обоих проектов
- ⏳ ExportManager (будущая фича для TranscribeIt)
  - Экспорт в SRT, VTT, TXT, DOCX, JSON

### Ключевые достижения
1. **Независимые копии кода**: WhisperService, ModelManager, LogManager с разными subsystems
2. **Раздельные настройки**: UserDefaults с префиксами `com.transcribeit.*` и `com.pushtotalk.*`
3. **Успешная компиляция**: Оба приложения собираются без ошибок ✅
4. **Разделение завершено**: PushToTalk упрощён, TranscribeIt полнофункционален
5. **Чистая архитектура**: Оба проекта имеют независимые target'ы и библиотеки
