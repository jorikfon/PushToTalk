# План рефакторинга архитектуры PushToTalk

## Цель рефакторинга

Улучшить архитектуру кодовой базы PushToTalk согласно современным стандартам Swift/macOS разработки, применяя принципы SOLID, Clean Architecture и лучшие практики Apple.

## Текущие проблемы архитектуры

### 1. Нарушение Single Responsibility Principle (SRP)

**AppDelegate.swift (560+ строк)**
- Смешивает инициализацию, бизнес-логику, UI-координацию
- Управляет сервисами, обрабатывает события, выполняет транскрипцию
- Публичные методы для тестирования нарушают инкапсуляцию

**MenuBarController.swift**
- Управление UI + отображение диалогов + обновление состояния
- Методы `showError`, `showInfo` должны быть в отдельном сервисе

**ModernSettingsView.swift (1473 строки)**
- Один View для всех настроек
- Нет разделения на компоненты
- Вся логика в View вместо ViewModel

### 2. Tight Coupling (Жёсткая связанность)

**Singleton Anti-Pattern**
```swift
AudioDeviceManager.shared
VocabularyManager.shared
ModelManager.shared
UserSettings.shared
```
- Невозможность тестирования с моками
- Скрытые зависимости
- Глобальное состояние

**Прямые зависимости**
```swift
class AppDelegate {
    private var whisperService: WhisperService?  // конкретный класс
    private var audioService: AudioCaptureService?  // конкретный класс
}
```
- Нет использования протоколов
- Невозможность подмены реализации

### 3. Отсутствие архитектурных слоёв

**Текущая структура:**
```
UI → Services → Utils (все вперемешку)
```

**Проблемы:**
- UI напрямую вызывает сервисы
- Бизнес-логика в AppDelegate
- Нет слоя координации
- Нет слоя презентации (ViewModels)

### 4. Смешение async/await и callbacks

```swift
// Async/await
await whisperService?.transcribe()

// Callbacks
keyboardMonitor?.onHotkeyPress = { ... }

// NotificationCenter
NotificationCenter.default.post(name: ...)
```

### 5. Hardcoded значения

**Строки в коде:**
```swift
"Настройки"
"Выход"
"Аудиоустройство"
```

**Magic numbers:**
```swift
.frame(width: 220)
.padding(24)
maxHistory = 50
```

**Цвета:**
```swift
.foregroundColor(.blue)
Color.red.opacity(0.1)
```

### 6. Отсутствие тестируемости

- Нет протоколов для сервисов
- Singleton затрудняет моки
- Бизнес-логика в UI
- Нет dependency injection

## Целевая архитектура

### Clean Architecture Layers

```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│   (Views, ViewModels, Controllers)  │
├─────────────────────────────────────┤
│        Coordination Layer           │
│      (Coordinators, Routers)        │
├─────────────────────────────────────┤
│         Business Logic Layer        │
│         (Use Cases, Interactors)    │
├─────────────────────────────────────┤
│          Service Layer              │
│    (Services, Repositories)         │
├─────────────────────────────────────┤
│          Infrastructure             │
│  (Frameworks, External Dependencies)│
└─────────────────────────────────────┘
```

### Dependency Injection Container

**Вместо Singleton:**
```swift
class ServiceContainer {
    // Lazy initialization
    lazy var whisperService: WhisperServiceProtocol = WhisperService(...)
    lazy var audioService: AudioCaptureServiceProtocol = AudioCaptureService(...)

    // Configuration
    let config: AppConfiguration
}
```

### Protocol-Oriented Programming

**Все сервисы через протоколы:**
```swift
protocol WhisperServiceProtocol {
    func transcribe(audioSamples: [Float]) async throws -> String
    func loadModel() async throws
}

protocol AudioCaptureServiceProtocol {
    func startRecording() throws
    func stopRecording() -> [Float]?
}
```

### MVVM Pattern для UI

**ViewModel отделён от View:**
```swift
class SettingsViewModel: ObservableObject {
    @Published var modelSize: String
    @Published var hotkey: Hotkey

    private let modelManager: ModelManagerProtocol

    func downloadModel(_ name: String) async throws { ... }
}
```

### Координаторы для навигации

**RecordingCoordinator:**
```swift
class RecordingCoordinator {
    func startRecording()
    func stopRecording()
    func handleTranscription(audio: [Float]) async
}
```

## Принципы рефакторинга

### SOLID Principles

**S - Single Responsibility**
- Каждый класс = одна ответственность
- AppDelegate только для lifecycle
- Coordinators для бизнес-логики
- ViewModels для презентации

**O - Open/Closed**
- Протоколы вместо конкретных классов
- Расширяемость через наследование/композицию

**L - Liskov Substitution**
- Протоколы обеспечивают взаимозаменяемость
- Моки для тестирования

**I - Interface Segregation**
- Узкие специализированные протоколы
- Не заставлять классы реализовывать ненужное

**D - Dependency Inversion**
- Зависимость от абстракций (протоколов)
- Не от конкретных реализаций

### DRY (Don't Repeat Yourself)

**Общие компоненты:**
- Constants для строк, чисел, цветов
- Extensions для повторяющейся логики
- Reusable UI компоненты

### KISS (Keep It Simple, Stupid)

- Простые, понятные имена
- Короткие методы (≤20 строк)
- Короткие классы (≤200 строк)
- Избегать over-engineering

### YAGNI (You Aren't Gonna Need It)

- Не создавать избыточную абстракцию
- Рефакторить по мере необходимости
- Начать с простого

## Целевая структура проекта

```
Sources/
├── App/
│   ├── AppDelegate.swift              (минимальный - lifecycle only)
│   ├── AppCoordinator.swift           (главный координатор)
│   └── ServiceContainer.swift         (DI контейнер)
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── StatusBarViewModel.swift
│   │   ├── SettingsViewModel.swift
│   │   └── HistoryViewModel.swift
│   │
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   └── MenuBarController.swift
│   │   │
│   │   ├── Settings/
│   │   │   ├── GeneralSettingsView.swift
│   │   │   ├── ModelSettingsView.swift
│   │   │   ├── HotkeySettingsView.swift
│   │   │   ├── VocabularySettingsView.swift
│   │   │   ├── AudioSettingsView.swift
│   │   │   ├── HistorySettingsView.swift
│   │   │   └── DebugSettingsView.swift
│   │   │
│   │   ├── Recording/
│   │   │   └── FloatingRecordingWindow.swift
│   │   │
│   │   └── Shared/
│   │       ├── VisualEffectBlur.swift
│   │       └── SettingsCard.swift
│   │
│   └── Controllers/
│       └── SettingsWindowController.swift
│
├── Coordinators/
│   ├── RecordingCoordinator.swift     (логика записи/транскрипции)
│   └── SettingsCoordinator.swift      (управление настройками)
│
├── Domain/
│   ├── UseCases/
│   │   ├── TranscribeAudioUseCase.swift
│   │   ├── ManageHotkeyUseCase.swift
│   │   └── ManageAudioDeviceUseCase.swift
│   │
│   └── Entities/
│       ├── TranscriptionEntry.swift
│       ├── Hotkey.swift
│       └── AudioDevice.swift
│
├── Services/
│   ├── Protocols/
│   │   ├── WhisperServiceProtocol.swift
│   │   ├── AudioCaptureServiceProtocol.swift
│   │   ├── TextInserterProtocol.swift
│   │   └── KeyboardMonitorProtocol.swift
│   │
│   ├── Implementation/
│   │   ├── WhisperService.swift
│   │   ├── AudioCaptureService.swift
│   │   ├── TextInserter.swift
│   │   └── KeyboardMonitor.swift
│   │
│   └── Configuration/
│       └── WhisperConfiguration.swift
│
├── Managers/
│   ├── Protocols/
│   │   ├── ModelManagerProtocol.swift
│   │   ├── AudioDeviceManagerProtocol.swift
│   │   └── VocabularyManagerProtocol.swift
│   │
│   └── Implementation/
│       ├── ModelManager.swift
│       ├── AudioDeviceManager.swift
│       ├── VocabularyManager.swift
│       ├── HotkeyManager.swift
│       ├── PermissionManager.swift
│       └── NotificationManager.swift
│
├── Utils/
│   ├── Constants/
│   │   ├── AppConstants.swift
│   │   ├── UIConstants.swift
│   │   └── Strings.swift
│   │
│   ├── Extensions/
│   │   ├── String+Extensions.swift
│   │   ├── Array+Extensions.swift
│   │   └── View+Extensions.swift
│   │
│   ├── Helpers/
│   │   ├── LogManager.swift
│   │   ├── UserSettings.swift
│   │   └── TranscriptionHistory.swift
│   │
│   ├── Audio/
│   │   ├── AudioNormalizer.swift
│   │   ├── SilenceDetector.swift
│   │   ├── SpectralVAD.swift
│   │   ├── AdaptiveVAD.swift
│   │   └── VoiceActivityDetector.swift
│   │
│   └── Media/
│       ├── SoundManager.swift
│       ├── AudioFeedbackManager.swift
│       ├── AudioDuckingManager.swift
│       ├── MicrophoneVolumeManager.swift
│       └── MediaRemoteManager.swift
│
└── Resources/
    ├── Localization/
    │   ├── en.lproj/
    │   │   └── Localizable.strings
    │   └── ru.lproj/
    │       └── Localizable.strings
    │
    └── Assets.xcassets/
```

## Ключевые улучшения

### 1. Dependency Injection вместо Singleton

**До:**
```swift
class AppDelegate {
    func setup() {
        ModelManager.shared.loadModel()
    }
}
```

**После:**
```swift
class AppDelegate {
    private let container = ServiceContainer()

    func setup() {
        container.modelManager.loadModel()
    }
}
```

### 2. Protocol-Oriented сервисы

**До:**
```swift
private var whisperService: WhisperService?
```

**После:**
```swift
private let whisperService: WhisperServiceProtocol
init(whisperService: WhisperServiceProtocol) {
    self.whisperService = whisperService
}
```

### 3. MVVM для UI

**До:**
```swift
struct SettingsView: View {
    func downloadModel() {
        ModelManager.shared.downloadModel()
    }
}
```

**После:**
```swift
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        Button("Download") {
            Task {
                await viewModel.downloadModel()
            }
        }
    }
}
```

### 4. Координаторы для бизнес-логики

**До:**
```swift
class AppDelegate {
    func handleHotkeyPress() {
        // 50+ строк логики записи
    }
}
```

**После:**
```swift
class RecordingCoordinator {
    func startRecording() { ... }
    func stopRecording() { ... }
}

class AppDelegate {
    private let recordingCoordinator: RecordingCoordinator

    func handleHotkeyPress() {
        recordingCoordinator.startRecording()
    }
}
```

### 5. Constants вместо hardcode

**До:**
```swift
.frame(width: 220)
Text("Настройки")
```

**После:**
```swift
.frame(width: UIConstants.sidebarWidth)
Text(Strings.Settings.title)
```

### 6. Модульная структура Settings

**До:**
```swift
ModernSettingsView.swift (1473 строки)
```

**После:**
```swift
GeneralSettingsView.swift (150 строк)
ModelSettingsView.swift (120 строк)
HotkeySettingsView.swift (100 строк)
...
```

## Инструменты и подходы

### Архитектурные паттерны

**MVVM (Model-View-ViewModel)**
- Разделение UI и бизнес-логики
- Тестируемость ViewModels
- Reactive programming с Combine

**Coordinator Pattern**
- Управление навигацией
- Изоляция бизнес-логики
- Переиспользуемость

**Repository Pattern**
- Абстракция доступа к данным
- Единая точка доступа
- Легко заменяемые источники

### Design Patterns

**Dependency Injection**
- Constructor injection
- Property injection
- Method injection

**Factory Pattern**
- Создание сложных объектов
- ServiceContainer как фабрика

**Observer Pattern**
- Combine publishers
- @Published properties
- Reactive updates

**Strategy Pattern**
- Разные стратегии транскрипции (realtime/quality)
- VAD алгоритмы
- Audio normalization

### Swift Best Practices

**Protocol-Oriented Programming**
- Protocols > Classes
- Protocol extensions
- Default implementations

**Value Types где возможно**
- Struct > Class
- Immutability
- Copy-on-write

**Async/Await вместо callbacks**
- Современный concurrency
- Structured concurrency
- Избегать callback hell

**SwiftUI Best Practices**
- Маленькие View компоненты
- @StateObject vs @ObservedObject
- Environment для DI

### Code Quality Tools

**SwiftLint**
- Автоматическая проверка стиля
- Консистентность кода
- Best practices

**SwiftFormat**
- Автоформатирование
- Единый стиль

**Swift Package Manager**
- Модульность
- Управление зависимостями

## Метрики качества кода

### Целевые показатели

**Cyclomatic Complexity**
- Методы: ≤10
- Классы: ≤20

**Lines of Code**
- Методы: ≤20 строк
- Классы: ≤200 строк
- Файлы: ≤300 строк

**Coupling**
- ≤5 зависимостей на класс
- Все через протоколы

**Test Coverage**
- Unit tests: ≥70%
- Integration tests: ≥50%

### Измеряемые улучшения

**До рефакторинга:**
- AppDelegate: 560 строк
- ModernSettingsView: 1473 строки
- 15+ Singleton классов
- 0% test coverage
- Нет протоколов для сервисов

**После рефакторинга:**
- AppDelegate: ≤100 строк
- Settings Views: ≤150 строк каждый
- 0 Singleton (только DI)
- ≥70% test coverage
- Все сервисы через протоколы

## Преимущества рефакторинга

### Для разработки

**Читаемость**
- Понятная структура
- Маленькие файлы
- Явные зависимости

**Поддерживаемость**
- Лёгко находить код
- Простые изменения
- Минимум side-effects

**Тестируемость**
- Unit tests для бизнес-логики
- Моки через протоколы
- Изолированное тестирование

**Расширяемость**
- Новые фичи легко добавляются
- Не ломается существующий код
- Open/Closed principle

### Для производительности

**Lazy initialization**
- ServiceContainer загружает по требованию
- Меньше памяти при старте

**Concurrency**
- Async/await для всех IO операций
- Structured concurrency
- Нет блокировок main thread

**Memory management**
- Weak references где нужно
- Избегание retain cycles
- Value types уменьшают overhead

### Для пользователя

**Надёжность**
- Меньше багов
- Предсказуемое поведение
- Graceful error handling

**Производительность**
- Быстрый запуск
- Плавный UI
- Отзывчивость

## Риски и ограничения

### Риски

**Временные затраты**
- Рефакторинг займёт время
- Может потребоваться переписать тесты

**Регрессия**
- Возможны новые баги
- Требуется тщательное тестирование

**Over-engineering**
- Риск излишней абстракции
- Баланс между простотой и гибкостью

### Ограничения

**Обратная совместимость**
- UserDefaults должны остаться теми же
- Файловая структура моделей не меняется

**Существующие зависимости**
- WhisperKit API остаётся как есть
- Carbon API для хоткеев неизменен

**SwiftUI ограничения**
- Некоторые паттерны сложнее в SwiftUI
- Требуется адаптация под SwiftUI lifecycle

## Итоги

Рефакторинг направлен на:
1. **Улучшение архитектуры** - Clean Architecture, SOLID
2. **Повышение тестируемости** - Protocols, DI, Unit tests
3. **Упрощение поддержки** - Маленькие файлы, явные зависимости
4. **Подготовку к масштабированию** - Модульность, расширяемость

Результат: **профессиональная, поддерживаемая кодовая база**, соответствующая стандартам Apple и индустрии.
