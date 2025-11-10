import Foundation
import Combine

/// ViewModel для управления состоянием статус-бара
public final class StatusBarViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Текущее состояние приложения
    @Published public private(set) var currentState: AppState = .ready

    /// Прогресс выполнения операции (0.0 - 1.0)
    @Published public private(set) var progress: Double = 0.0

    /// Текущий размер модели
    @Published public private(set) var modelSize: String = ""

    /// Текущее сообщение для отображения
    @Published public private(set) var statusMessage: String = ""

    /// Иконка для статус-бара
    @Published public private(set) var iconName: String = "mic.fill"

    // MARK: - Private Properties

    private let modelManager: any ModelManagerProtocol
    private let whisperService: any WhisperServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public init(
        modelManager: any ModelManagerProtocol,
        whisperService: any WhisperServiceProtocol
    ) {
        self.modelManager = modelManager
        self.whisperService = whisperService

        setupBindings()
        updateModelInfo()
    }

    // MARK: - Public Methods

    /// Устанавливает состояние "Запись"
    public func setRecordingState() {
        currentState = .recording
        statusMessage = Strings.Status.recording
        iconName = "mic.fill"
        progress = 0.0
    }

    /// Устанавливает состояние "Обработка"
    public func setProcessingState(progress: Double = 0.0) {
        currentState = .processing
        statusMessage = Strings.Status.processing
        iconName = "waveform"
        self.progress = progress
    }

    /// Устанавливает состояние "Готов"
    public func setReadyState() {
        currentState = .ready
        statusMessage = Strings.Status.ready
        iconName = "mic.fill"
        progress = 0.0
    }

    /// Устанавливает состояние "Ошибка"
    public func setErrorState(message: String) {
        currentState = .error
        statusMessage = message
        iconName = "exclamationmark.triangle.fill"
        progress = 0.0
    }

    /// Обновляет информацию о текущей модели
    public func updateModelInfo() {
        modelSize = whisperService.currentModelSize

        // Обновляем сообщение готовности с информацией о модели
        if currentState == .ready {
            statusMessage = "\(Strings.Status.ready) (\(modelSize))"
        }
    }

    /// Устанавливает прогресс выполнения
    public func updateProgress(_ progress: Double) {
        self.progress = min(max(progress, 0.0), 1.0)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Для протоколов используем подход с таймером или уведомлениями
        // В данном случае updateModelInfo() будет вызываться явно при изменении модели
    }
}

// MARK: - AppState

public extension StatusBarViewModel {
    enum AppState: Equatable {
        case ready
        case recording
        case processing
        case error

        var color: String {
            switch self {
            case .ready:
                return "green"
            case .recording:
                return "red"
            case .processing:
                return "orange"
            case .error:
                return "red"
            }
        }
    }
}
