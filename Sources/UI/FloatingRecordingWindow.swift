import SwiftUI
import AppKit

/// Всплывающее окно для отображения статуса записи и транскрипции
/// Появляется в правом нижнем углу экрана при нажатии hotkey
public class FloatingRecordingWindow: NSWindow {
    private var recordingView: NSHostingController<RecordingStatusView>?
    private var viewModel: RecordingViewModel

    public init() {
        self.viewModel = RecordingViewModel()
        // Создаем окно по центру экрана
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 200

        let windowFrame = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        super.init(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Настройка окна
        self.level = .floating  // Поверх всех окон
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Создаем SwiftUI view с ViewModel
        let statusView = RecordingStatusView(viewModel: viewModel)
        recordingView = NSHostingController(rootView: statusView)

        if let contentView = recordingView?.view {
            self.contentView = contentView
        }

        // Скрываем окно по умолчанию
        self.orderOut(nil)

        LogManager.app.debug("FloatingRecordingWindow инициализировано")
    }

    /// Показать окно с анимацией (запись началась)
    public func showRecording(maxDuration: TimeInterval = 60.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Сразу показываем окно с подсказкой (пустой текст)
            self.viewModel.updateState(.recordingWithText(partialText: ""))

            // Обновляем название аудиоустройства
            let deviceName = AudioDeviceManager.shared.selectedDevice?.name ?? "Default Microphone"
            self.viewModel.updateAudioDevice(deviceName)

            // Запускаем таймер обратного отсчета
            self.viewModel.startTimer(maxDuration: maxDuration)

            // Показываем окно с fade-in анимацией
            self.alphaValue = 0
            self.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 1.0
            })

            LogManager.app.debug("FloatingRecordingWindow: показано (запись) с лимитом \(Int(maxDuration))с")
        }
    }

    /// Обновить промежуточный текст во время записи
    public func updatePartialTranscription(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.viewModel.updateState(.recordingWithText(partialText: text))
            LogManager.app.debug("FloatingRecordingWindow: обновлен частичный текст")
        }
    }

    /// Обновить на состояние транскрипции (вызывает анимацию трансформации)
    public func showProcessing() {
        // Вызываем анимацию трансформации в компактный режим
        animateToCompactMode()
    }

    /// Анимация трансформации в компактный режим с перемещением
    public func animateToCompactMode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. Сначала меняем состояние на компактное (SwiftUI автоматически анимирует размер)
            self.viewModel.updateState(.processingCompact)

            // 2. Вычисляем новую позицию окна (верхняя часть экрана, 10% ниже центра)
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            let compactSize: CGFloat = 60

            // Позиция: по центру горизонтально, 10% ниже середины по вертикали
            let newX = screenFrame.midX - compactSize / 2
            let newY = screenFrame.midY + screenFrame.height * 0.1 - compactSize / 2

            let newFrame = NSRect(
                x: newX,
                y: newY,
                width: compactSize,
                height: compactSize
            )

            // 3. Анимируем перемещение NSWindow
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            })

            LogManager.app.debug("FloatingRecordingWindow: трансформация в компактный режим")
        }
    }

    /// Показать результат транскрипции
    public func showResult(_ text: String, duration: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Сразу скрываем окно после транскрипции
            self.hide()

            LogManager.app.debug("FloatingRecordingWindow: результат показан, окно скрыто")
        }
    }

    /// Показать ошибку
    public func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.viewModel.updateState(.error(message: message))

            // Автоматически скрыть через 3 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.hide()
            }

            LogManager.app.error("FloatingRecordingWindow: ошибка показана")
        }
    }

    /// Сбросить таймер (при стоп-слове)
    public func resetTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewModel.resetTimer()
            LogManager.app.debug("FloatingRecordingWindow: таймер сброшен")
        }
    }

    /// Скрыть окно с плавной fade-out анимацией
    public func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Останавливаем таймер
            self.viewModel.stopTimer()

            // Плавное исчезновение
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 0
            }) {
                // После завершения анимации скрываем окно
                self.orderOut(nil)
                LogManager.app.debug("FloatingRecordingWindow: скрыто с fade-out")
            }
        }
    }
}

// MARK: - View Model

class RecordingViewModel: ObservableObject {
    @Published var state: RecordingState = .recording
    @Published var pulseAnimation = false
    @Published var audioDeviceName: String = ""
    @Published var remainingTime: TimeInterval = 60.0  // Оставшееся время

    private var startTime: Date?
    private var maxDuration: TimeInterval = 60.0
    private var updateTimer: Timer?

    func updateState(_ newState: RecordingState) {
        state = newState
        if case .recording = newState {
            pulseAnimation = false
            // Сброс для перезапуска анимации
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pulseAnimation = true
            }
        }
    }

    func updateAudioDevice(_ deviceName: String) {
        audioDeviceName = deviceName
    }

    /// Запустить таймер обратного отсчета
    func startTimer(maxDuration: TimeInterval) {
        self.maxDuration = maxDuration
        self.startTime = Date()
        self.remainingTime = maxDuration

        // Обновляем каждую секунду
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }
    }

    /// Сбросить таймер (при стоп-слове)
    func resetTimer() {
        self.startTime = Date()
        self.remainingTime = maxDuration
    }

    /// Остановить таймер
    func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Обновить оставшееся время
    private func updateRemainingTime() {
        guard let startTime = startTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        remainingTime = max(0, maxDuration - elapsed)
    }

    deinit {
        updateTimer?.invalidate()
    }
}

// MARK: - Recording Status View

enum RecordingState: Equatable {
    case recording
    case recordingWithText(partialText: String)  // Запись с промежуточным текстом
    case processing
    case processingCompact  // Компактный режим обработки с анимацией
    case success(text: String, duration: TimeInterval)
    case error(message: String)
}

struct RecordingStatusView: View {
    @ObservedObject var viewModel: RecordingViewModel

    // Форматирование времени в MM:SS
    private var formattedTime: String {
        let minutes = Int(viewModel.remainingTime) / 60
        let seconds = Int(viewModel.remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Цвет таймера (красный если меньше 10 секунд)
    private var timerColor: Color {
        viewModel.remainingTime < 10 ? .red : .secondary
    }

    var body: some View {
        ZStack {
            // Liquid Glass Background
            ZStack {
                // Основной blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Градиентные overlays
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.18),
                        Color.white.opacity(0.08)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)

                // Динамическое свечение
                stateGlow
                    .blendMode(.softLight)

                // Градиентная граница
                RoundedRectangle(cornerRadius: dynamicCornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.6), location: 0.0),
                                .init(color: Color.white.opacity(0.25), location: 0.5),
                                .init(color: Color.white.opacity(0.5), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .cornerRadius(dynamicCornerRadius)
            .shadow(color: stateShadowColor.opacity(0.25), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)

            // Контент
            contentView
                .padding(20)
        }
        .frame(width: dynamicWidth, height: dynamicHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.state)
    }

    // Динамические размеры окна с плавной анимацией
    private var dynamicWidth: CGFloat {
        switch viewModel.state {
        case .processingCompact:
            return 60
        default:
            return 400
        }
    }

    private var dynamicHeight: CGFloat {
        switch viewModel.state {
        case .processingCompact:
            return 60
        default:
            return 180
        }
    }

    // Динамический cornerRadius
    private var dynamicCornerRadius: CGFloat {
        switch viewModel.state {
        case .processingCompact:
            return 30  // Круглое окно
        default:
            return 20
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .recording:
            textTranscriptionView(partialText: "")
        case .recordingWithText(let partialText):
            textTranscriptionView(partialText: partialText)
        case .processing:
            textTranscriptionView(partialText: "")
        case .processingCompact:
            compactProcessingView
        case .success, .error:
            EmptyView() // Окно сразу закрывается
        }
    }

    // MARK: - Dynamic State Effects

    /// Динамическое свечение фона в зависимости от состояния
    @ViewBuilder
    private var stateGlow: some View {
        switch viewModel.state {
        case .recording, .recordingWithText, .processing:
            // Красное пульсирующее свечение при записи
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.red.opacity(0.12),
                    Color.orange.opacity(0.06),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 200
            )
        case .processingCompact:
            // Синее пульсирующее свечение при обработке
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.15),
                    Color.cyan.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 5,
                endRadius: 50
            )
        default:
            Color.clear
        }
    }

    /// Цвет тени в зависимости от состояния
    private var stateShadowColor: Color {
        switch viewModel.state {
        case .recording, .recordingWithText, .processing:
            return .red
        case .processingCompact:
            return .blue
        default:
            return .clear
        }
    }

    // MARK: - Minimalist Views

    /// Вид с текстом транскрипции
    private func textTranscriptionView(partialText: String) -> some View {
        VStack(spacing: 12) {
            // Маленький микрофон сверху с названием устройства и таймером
            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.red, .pink]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(viewModel.pulseAnimation ? 1.2 : 0.8)
                    .opacity(viewModel.pulseAnimation ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)

                if !viewModel.audioDeviceName.isEmpty {
                    Text(viewModel.audioDeviceName)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }

                Spacer()

                // Обратный таймер
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundColor(timerColor.opacity(0.8))

                    Text(formattedTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(timerColor)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.remainingTime < 10)
                }
            }
            .padding(.bottom, 4)

            // Чистый текст без рамок и блоков
            ScrollView {
                Text(partialText.isEmpty ? "Говорите, после отпустите hotkey и я вставлю текст" : partialText)
                    .font(.body)
                    .foregroundColor(partialText.isEmpty ? .secondary.opacity(0.6) : .primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: partialText)
            }
            .frame(maxHeight: 120)
        }
    }

    /// Компактный вид обработки с пульсирующей волной
    private var compactProcessingView: some View {
        ZStack {
            // Пульсирующая волна
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .cyan]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(viewModel.pulseAnimation ? 1.15 : 1.0)
                .opacity(viewModel.pulseAnimation ? 1.0 : 0.6)
                .animation(
                    .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: viewModel.pulseAnimation
                )
                .onAppear {
                    // Запускаем пульсацию при появлении
                    viewModel.pulseAnimation = true
                }
        }
    }

}

// MARK: - Visual Effect View для blur эффекта

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
