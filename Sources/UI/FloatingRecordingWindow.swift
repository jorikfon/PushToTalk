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
    public func showRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Сразу показываем окно с подсказкой (пустой текст)
            self.viewModel.updateState(.recordingWithText(partialText: ""))

            // Показываем окно с fade-in анимацией
            self.alphaValue = 0
            self.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 1.0
            })

            LogManager.app.debug("FloatingRecordingWindow: показано (запись)")
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

    /// Обновить на состояние транскрипции
    public func showProcessing() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.viewModel.updateState(.processing)
            LogManager.app.debug("FloatingRecordingWindow: обработка")
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

    /// Скрыть окно с анимацией
    public func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.orderOut(nil)
            })

            LogManager.app.debug("FloatingRecordingWindow: скрыто")
        }
    }
}

// MARK: - View Model

class RecordingViewModel: ObservableObject {
    @Published var state: RecordingState = .recording
    @Published var pulseAnimation = false

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
}

// MARK: - Recording Status View

enum RecordingState: Equatable {
    case recording
    case recordingWithText(partialText: String)  // Запись с промежуточным текстом
    case processing
    case success(text: String, duration: TimeInterval)
    case error(message: String)
}

struct RecordingStatusView: View {
    @ObservedObject var viewModel: RecordingViewModel

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
                RoundedRectangle(cornerRadius: 20)
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
            .cornerRadius(20)
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
        return 400
    }

    private var dynamicHeight: CGFloat {
        return 180
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
        default:
            Color.clear
        }
    }

    /// Цвет тени в зависимости от состояния
    private var stateShadowColor: Color {
        switch viewModel.state {
        case .recording, .recordingWithText, .processing:
            return .red
        default:
            return .clear
        }
    }

    // MARK: - Minimalist Views

    /// Вид с текстом транскрипции
    private func textTranscriptionView(partialText: String) -> some View {
        VStack(spacing: 12) {
            // Маленький микрофон сверху
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

                Spacer()
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
