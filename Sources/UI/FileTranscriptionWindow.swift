import SwiftUI
import AppKit
import PushToTalkCore

/// Окно для отображения прогресса и результатов транскрипции файлов
/// FIX: Используем NSPanel вместо NSWindow для предотвращения краша при закрытии
public class FileTranscriptionWindow: NSPanel {
    private var hostingController: NSHostingController<FileTranscriptionView>?
    public var viewModel: FileTranscriptionViewModel
    public var onClose: ((FileTranscriptionWindow) -> Void)?

    public convenience init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 500

        let windowFrame = NSRect(
            x: screenFrame.midX - windowWidth / 2,
            y: screenFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        // NSPanel инициализация (вместо NSWindow)
        self.init(
            contentRect: windowFrame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
    }

    public override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        // Инициализируем ViewModel
        self.viewModel = FileTranscriptionViewModel()

        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        // Настройка окна
        self.title = "File Transcription"
        self.isFloatingPanel = false
        self.becomesKeyOnlyIfNeeded = false

        // Создаём SwiftUI view с ViewModel
        let swiftUIView = FileTranscriptionView(viewModel: viewModel)
        let hosting = NSHostingController(rootView: swiftUIView)
        self.hostingController = hosting

        // Настраиваем content view
        self.contentView = hosting.view

        LogManager.app.info("FileTranscriptionWindow: NSPanel создан с SwiftUI")
    }

    /// Начать транскрипцию файлов
    public func startTranscription(files: [URL]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.viewModel.startTranscription(files: files)
            self.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Закрыть окно
    public func hideWindow() {
        DispatchQueue.main.async { [weak self] in
            self?.orderOut(nil)
        }
    }

    deinit {
        LogManager.app.info("FileTranscriptionWindow: deinit - очищаем ресурсы")
        hostingController = nil
        onClose?(self)
    }
}

/// ViewModel для окна транскрипции файлов
public class FileTranscriptionViewModel: ObservableObject {
    @Published var state: TranscriptionState = .idle
    @Published var currentFile: String = ""
    @Published var progress: Double = 0.0

    // ВАЖНО: Используем willSet вместо @Published для массива, чтобы избежать проблем с памятью
    var transcriptions: [FileTranscription] = [] {
        willSet {
            objectWillChange.send()
        }
    }

    private var fileQueue: [URL] = []
    private var currentIndex = 0

    public init() {
        // Простая инициализация без @Published массивов
        self.transcriptions = []
        self.fileQueue = []
        self.state = .idle
        self.currentFile = ""
        self.progress = 0.0
        self.currentIndex = 0
    }

    public func startTranscription(files: [URL]) {
        self.fileQueue = files
        self.currentIndex = 0
        self.transcriptions = []
        self.state = .processing
        // Транскрипция будет запущена извне через AppDelegate
    }

    public func updateProgress(file: String, progress: Double) {
        self.currentFile = file
        self.progress = progress
    }

    public func addTranscription(file: String, text: String) {
        let transcription = FileTranscription(fileName: file, text: text, status: .success, dialogue: nil)
        transcriptions.append(transcription)
    }

    public func addDialogue(file: String, dialogue: DialogueTranscription) {
        let transcription = FileTranscription(
            fileName: file,
            text: dialogue.formatted(),
            status: .success,
            dialogue: dialogue
        )
        transcriptions.append(transcription)
    }

    public func addError(file: String, error: String) {
        let transcription = FileTranscription(fileName: file, text: error, status: .error, dialogue: nil)
        transcriptions.append(transcription)
    }

    public func complete() {
        self.state = .completed
        self.currentFile = ""
        self.progress = 1.0
    }

    public enum TranscriptionState {
        case idle
        case processing
        case completed
    }
}

/// Модель транскрипции файла
struct FileTranscription: Identifiable {
    let id = UUID()
    let fileName: String
    let text: String
    let status: Status
    let dialogue: DialogueTranscription?  // Опциональный диалог для стерео

    enum Status {
        case success
        case error
    }
}

/// SwiftUI view для окна транскрипции
struct FileTranscriptionView: View {
    @ObservedObject var viewModel: FileTranscriptionViewModel

    var body: some View {
        ZStack {
            // Фон с Liquid Glass эффектом
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Заголовок
                Text("File Transcription")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.top, 20)

                // Прогресс
                if viewModel.state == .processing {
                    VStack(spacing: 12) {
                        Text("Transcribing: \(viewModel.currentFile)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        ProgressView(value: viewModel.progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(maxWidth: 500)

                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                }

                // Результаты транскрипции
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.transcriptions) { transcription in
                            TranscriptionResultCard(transcription: transcription)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Кнопки действий
                if viewModel.state == .completed {
                    HStack(spacing: 12) {
                        Button(action: {
                            copyAllTranscriptions()
                        }) {
                            Label("Copy All", systemImage: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            saveAllTranscriptions()
                        }) {
                            Label("Save All", systemImage: "square.and.arrow.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            closeWindow()
                        }) {
                            Label("Close", systemImage: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func copyAllTranscriptions() {
        let text = viewModel.transcriptions
            .filter { $0.status == .success }
            .map { "[\($0.fileName)]\n\($0.text)" }
            .joined(separator: "\n\n---\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        LogManager.app.success("Все транскрипции скопированы в буфер обмена")
    }

    private func saveAllTranscriptions() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "transcriptions.txt"
        savePanel.message = "Save all transcriptions to file"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let text = viewModel.transcriptions
                    .filter { $0.status == .success }
                    .map { "[\($0.fileName)]\n\($0.text)" }
                    .joined(separator: "\n\n---\n\n")

                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                    LogManager.app.success("Транскрипции сохранены: \(url.path)")
                } catch {
                    LogManager.app.failure("Ошибка сохранения транскрипций", error: error)
                }
            }
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

/// Карточка с результатом транскрипции файла
struct TranscriptionResultCard: View {
    let transcription: FileTranscription

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Имя файла
            HStack {
                Image(systemName: transcription.status == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(transcription.status == .success ? .green : .red)
                Text(transcription.fileName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()

                // Кнопка копирования
                if transcription.status == .success {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(transcription.text, forType: .string)
                        LogManager.app.success("Текст скопирован")
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Текст транскрипции или диалог
            if let dialogue = transcription.dialogue, dialogue.isStereo {
                // Показываем диалог для стерео
                VStack(alignment: .leading, spacing: 8) {
                    // Индикатор стерео
                    HStack {
                        Image(systemName: "headphones")
                            .foregroundColor(.blue)
                        Text("Stereo Dialogue")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    // Реплики дикторов
                    ForEach(0..<dialogue.turns.count, id: \.self) { index in
                        let turn = dialogue.turns[index]
                        HStack(alignment: .top, spacing: 8) {
                            // Индикатор диктора
                            Text(turn.speaker.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(turn.speaker == .left ? .blue : .orange)
                                .frame(width: 80, alignment: .leading)

                            // Текст реплики
                            Text(turn.text)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                // Обычный текст для моно
                Text(transcription.text)
                    .font(.system(size: 13))
                    .foregroundColor(transcription.status == .success ? .primary : .red)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

/// Visual Effect Blur для Liquid Glass эффекта
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
