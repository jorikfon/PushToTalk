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
    @Published var modelName: String = ""  // Текущая модель Whisper

    // ВАЖНО: Используем willSet вместо @Published для массива, чтобы избежать проблем с памятью
    var transcriptions: [FileTranscription] = [] {
        willSet {
            objectWillChange.send()
        }
    }

    // Глобальный аудио плеер для всех транскрипций
    let globalAudioPlayer = AudioPlayerManager()

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
        self.modelName = ""
    }

    public func setModel(_ modelName: String) {
        self.modelName = modelName
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

    public func addTranscription(file: String, text: String, fileURL: URL? = nil) {
        let transcription = FileTranscription(fileName: file, text: text, status: .success, dialogue: nil, fileURL: fileURL)
        transcriptions.append(transcription)
    }

    public func addDialogue(file: String, dialogue: DialogueTranscription, fileURL: URL? = nil) {
        let transcription = FileTranscription(
            fileName: file,
            text: dialogue.formatted(),
            status: .success,
            dialogue: dialogue,
            fileURL: fileURL
        )
        transcriptions.append(transcription)
    }

    /// Обновляет существующий диалог или создаёт новый (для постепенного добавления реплик)
    public func updateDialogue(file: String, dialogue: DialogueTranscription, fileURL: URL? = nil) {
        LogManager.app.debug("updateDialogue: \(file), turns: \(dialogue.turns.count), isStereo: \(dialogue.isStereo)")

        // Ищем существующую транскрипцию для этого файла
        if let index = transcriptions.firstIndex(where: { $0.fileName == file }) {
            // Обновляем существующую
            let updated = FileTranscription(
                fileName: file,
                text: dialogue.formatted(),
                status: .success,
                dialogue: dialogue,
                fileURL: fileURL
            )
            transcriptions[index] = updated
            LogManager.app.debug("Обновлена существующая транскрипция #\(index)")
        } else {
            // Создаём новую
            addDialogue(file: file, dialogue: dialogue, fileURL: fileURL)
            LogManager.app.debug("Создана новая транскрипция")
        }
    }

    public func addError(file: String, error: String) {
        let transcription = FileTranscription(fileName: file, text: error, status: .error, dialogue: nil, fileURL: nil)
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
    let fileURL: URL?  // URL оригинального файла для воспроизведения

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
                VStack(spacing: 8) {
                    Text("File Transcription")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    // Отображение модели Whisper
                    if !viewModel.modelName.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("Model: \(viewModel.modelName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
                            TranscriptionResultCard(
                                transcription: transcription,
                                audioPlayer: viewModel.globalAudioPlayer
                            )
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
    @ObservedObject var audioPlayer: AudioPlayerManager

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

            // Аудио плеер (если есть URL файла)
            if let fileURL = transcription.fileURL {
                AudioPlayerView(audioPlayer: audioPlayer, fileURL: fileURL)
                    .padding(.vertical, 8)
            }

            // Текст транскрипции или диалог
            if let dialogue = transcription.dialogue, dialogue.isStereo {
                // Показываем диалог для стерео в виде чата
                DialogueChatView(dialogue: dialogue, audioPlayer: audioPlayer)
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
        .onAppear {
            // Загружаем аудио файл при появлении
            if let fileURL = transcription.fileURL {
                do {
                    try audioPlayer.loadAudio(from: fileURL)
                } catch {
                    LogManager.app.failure("Ошибка загрузки аудио", error: error)
                }
            }
        }
    }
}

/// Чат-подобное отображение диалога с timeline
struct DialogueChatView: View {
    let dialogue: DialogueTranscription
    @ObservedObject var audioPlayer: AudioPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок с информацией
            HStack {
                Image(systemName: "headphones")
                    .foregroundColor(.blue)
                Text("Stereo Dialogue")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Общая длительность
                Text(formatDuration(dialogue.totalDuration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Timeline с репликами (отсортированные по времени)
            // УБРАН ScrollView и maxHeight - используем естественный layout
            if dialogue.sortedByTime.isEmpty {
                Text("Нет распознанных реплик")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(dialogue.sortedByTime) { turn in
                        ChatMessageBubble(turn: turn, audioPlayer: audioPlayer)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Пузырь сообщения в стиле мессенджера
struct ChatMessageBubble: View {
    let turn: DialogueTranscription.Turn
    @ObservedObject var audioPlayer: AudioPlayerManager

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Левое выравнивание для Speaker 1
            if turn.speaker == .left {
                messageContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 60)  // Отступ справа
            } else {
                // Правое выравнивание для Speaker 2
                Spacer(minLength: 60)  // Отступ слева
                messageContent
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var messageContent: some View {
        VStack(alignment: turn.speaker == .left ? .leading : .trailing, spacing: 4) {
            // Заголовок с именем диктора и временем
            HStack(spacing: 6) {
                if turn.speaker == .left {
                    speakerLabel
                    timeLabel
                } else {
                    timeLabel
                    speakerLabel
                }
            }

            // Текст сообщения (кликабельный для перехода к времени)
            Text(turn.text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .cornerRadius(16)
                .multilineTextAlignment(turn.speaker == .left ? .leading : .trailing)
                .onTapGesture {
                    // Переход к времени реплики и начало воспроизведения
                    audioPlayer.seekAndPlay(to: turn.startTime)
                    LogManager.app.info("Переход к реплике: \(turn.startTime)s")
                }
                .help("Click to play from this time")
        }
    }

    private var speakerLabel: some View {
        Text(turn.speaker.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(turn.speaker == .left ? .blue : .orange)
    }

    private var timeLabel: some View {
        Text(formatTimestamp(turn.startTime))
            .font(.system(size: 9, weight: .regular))
            .foregroundColor(.secondary)
    }

    private var bubbleColor: Color {
        if turn.speaker == .left {
            return Color.blue.opacity(0.15)
        } else {
            return Color.orange.opacity(0.15)
        }
    }

    private func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Аудио плеер для воспроизведения файла
struct AudioPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    let fileURL: URL

    var body: some View {
        VStack(spacing: 8) {
            // Прогресс бар
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фоновая дорожка
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Прогресс
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(audioPlayer.currentTime / max(audioPlayer.duration, 1)), height: 4)
                        .cornerRadius(2)
                }
                .frame(height: 4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newTime = Double(value.location.x / geometry.size.width) * audioPlayer.duration
                            audioPlayer.seek(to: newTime)
                        }
                )
            }
            .frame(height: 4)

            // Контролы плеера
            HStack(spacing: 12) {
                // Кнопка Play/Pause
                Button(action: {
                    audioPlayer.togglePlayback()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())

                // Текущее время
                Text(formatTime(audioPlayer.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                // Общая длительность
                Text(formatTime(audioPlayer.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                // Громкость
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Slider(value: Binding(
                        get: { Double(audioPlayer.volume) },
                        set: { audioPlayer.setVolume(Float($0)) }
                    ), in: 0...1)
                    .frame(width: 60)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
