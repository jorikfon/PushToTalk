import SwiftUI
import AppKit

/// Всплывающее окно для отображения статуса записи и транскрипции
/// Появляется в правом нижнем углу экрана при нажатии hotkey
public class FloatingRecordingWindow: NSWindow {
    private var recordingView: NSHostingController<RecordingStatusView>?
    private var viewModel: RecordingViewModel

    public init() {
        self.viewModel = RecordingViewModel()
        // Создаем окно в правом нижнем углу экрана
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 120
        let padding: CGFloat = 20

        let windowFrame = NSRect(
            x: screenFrame.maxX - windowWidth - padding,
            y: screenFrame.minY + padding,
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

            // Обновляем состояние view через ViewModel
            self.viewModel.updateState(.recording)

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

            self.viewModel.updateState(.success(text: text, duration: duration))

            // Автоматически скрыть через 2 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.hide()
            }

            LogManager.app.debug("FloatingRecordingWindow: результат показан")
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

enum RecordingState {
    case recording
    case processing
    case success(text: String, duration: TimeInterval)
    case error(message: String)
}

struct RecordingStatusView: View {
    @ObservedObject var viewModel: RecordingViewModel

    var body: some View {
        ZStack {
            // Фон с blur эффектом
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            // Контент
            VStack(spacing: 12) {
                switch viewModel.state {
                case .recording:
                    recordingView
                case .processing:
                    processingView
                case .success(let text, let duration):
                    successView(text: text, duration: duration)
                case .error(let message):
                    errorView(message: message)
                }
            }
            .padding(16)
        }
        .frame(width: 280, height: 120)
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            // Иконка микрофона с пульсацией
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)
                .scaleEffect(viewModel.pulseAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                .onAppear {
                    viewModel.pulseAnimation = true
                }

            Text("Recording...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Release hotkey to transcribe")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var processingView: some View {
        VStack(spacing: 12) {
            // Крутящееся колесико
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())

            Text("Transcribing...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Using Whisper AI")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func successView(text: String, duration: TimeInterval) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)

            Text("Success!")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\"\(text.prefix(30))\(text.count > 30 ? "..." : "")\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(String(format: "%.1fs", duration))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text("Error")
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
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
