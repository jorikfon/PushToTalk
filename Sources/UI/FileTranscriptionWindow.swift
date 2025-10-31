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
    @Published public var state: TranscriptionState = .idle
    @Published public var currentFile: String = ""
    @Published public var progress: Double = 0.0
    @Published public var modelName: String = ""  // Текущая модель Whisper
    @Published public var vadInfo: String = ""  // Информация о VAD алгоритме

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

    // Показываем только первую (текущую) транскрипцию
    private var currentTranscription: FileTranscription? {
        viewModel.transcriptions.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Компактный заголовок
            HStack {
                // Имя файла
                if let transcription = currentTranscription {
                    Text(transcription.fileName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                } else {
                    Text("File Transcription")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Модель и VAD
                HStack(spacing: 12) {
                    if !viewModel.modelName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                            Text(viewModel.modelName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !viewModel.vadInfo.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text(viewModel.vadInfo)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Прогресс бар (если транскрибируется)
            if viewModel.state == .processing {
                ProgressView(value: viewModel.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
            }

            // Содержимое транскрипции
            if let transcription = currentTranscription {
                VStack(spacing: 0) {
                    // Аудио плеер
                    if let fileURL = transcription.fileURL {
                        AudioPlayerView(audioPlayer: viewModel.globalAudioPlayer, fileURL: fileURL)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                    }

                    // Диалог или текст
                    if let dialogue = transcription.dialogue, dialogue.isStereo {
                        TimelineSyncedDialogueView(dialogue: dialogue, audioPlayer: viewModel.globalAudioPlayer)
                    } else {
                        ScrollView {
                            Text(transcription.text)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
                .onAppear {
                    // Загружаем аудио файл при появлении
                    if let fileURL = transcription.fileURL {
                        do {
                            try viewModel.globalAudioPlayer.loadAudio(from: fileURL)
                        } catch {
                            LogManager.app.failure("Ошибка загрузки аудио", error: error)
                        }
                    }
                }
            } else {
                // Пустое состояние
                Spacer()
                Text("No transcription yet")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
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
                // Показываем диалог для стерео в виде двух синхронизированных колонок
                TimelineSyncedDialogueView(dialogue: dialogue, audioPlayer: audioPlayer)
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

/// Отображение диалога в виде двух синхронизированных по времени колонок
struct TimelineSyncedDialogueView: View {
    let dialogue: DialogueTranscription
    @ObservedObject var audioPlayer: AudioPlayerManager

    // Адаптивная высота: вычисляем оптимальный масштаб
    private var pixelsPerSecond: CGFloat {
        calculateAdaptiveScale()
    }

    // Максимальная и минимальная высота timeline
    private let maxTimelineHeight: CGFloat = 600  // Максимум 600px
    private let minPixelsPerSecond: CGFloat = 15  // Минимум 15px/sec (более компактно)
    private let maxPixelsPerSecond: CGFloat = 80  // Максимум 80px/sec (для очень коротких)

    /// Вычисляет адаптивный масштаб timeline на основе сжатой длительности
    /// Диалог уже сжат (периоды тишины удалены), используем totalDuration напрямую
    private func calculateAdaptiveScale() -> CGFloat {
        // Если нет реплик, используем средний масштаб
        guard !dialogue.turns.isEmpty else { return 40 }

        // Диалог уже сжат, используем totalDuration
        let duration = dialogue.totalDuration
        guard duration > 0 else { return 40 }

        // Вычисляем идеальный масштаб, чтобы вместить диалог в maxTimelineHeight
        let idealScale = maxTimelineHeight / CGFloat(duration)

        // Ограничиваем масштаб для читабельности
        return max(minPixelsPerSecond, min(maxPixelsPerSecond, idealScale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок с информацией
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.blue)
                Text("Timeline View")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Общая длительность
                Text(formatDuration(dialogue.totalDuration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            if dialogue.turns.isEmpty {
                Text("Нет распознанных реплик")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Прокручиваемая область с timeline
                ScrollView {
                    // Основной layout: временная шкала + две колонки
                    HStack(alignment: .top, spacing: 12) {
                        // Временная шкала слева (диалог уже сжат, показываем с 0)
                        TimelineAxis(
                            totalDuration: dialogue.totalDuration,
                            pixelsPerSecond: pixelsPerSecond
                        )
                        .frame(width: 50)

                        // Две синхронизированные колонки
                        HStack(alignment: .top, spacing: 8) {
                            // Колонка Speaker 1 (левый канал)
                            SpeakerColumn(
                                turns: dialogue.turns.filter { $0.speaker == .left },
                                speaker: .left,
                                totalDuration: dialogue.totalDuration,
                                pixelsPerSecond: pixelsPerSecond,
                                audioPlayer: audioPlayer
                            )
                            .frame(maxWidth: .infinity)

                            // Разделитель
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1)

                            // Колонка Speaker 2 (правый канал)
                            SpeakerColumn(
                                turns: dialogue.turns.filter { $0.speaker == .right },
                                speaker: .right,
                                totalDuration: dialogue.totalDuration,
                                pixelsPerSecond: pixelsPerSecond,
                                audioPlayer: audioPlayer
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: 400)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Временная шкала (ось времени) - диалог уже сжат, показываем с 0
struct TimelineAxis: View {
    let totalDuration: TimeInterval
    let pixelsPerSecond: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Вертикальная линия
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .offset(x: 48)

                // Временные метки каждые 10 секунд (или чаще для коротких файлов)
                ForEach(timeMarks, id: \.self) { time in
                    HStack(spacing: 4) {
                        Text(formatTime(time))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)

                        // Короткая горизонтальная черта
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 6, height: 1)
                    }
                    .offset(y: CGFloat(time) * pixelsPerSecond - 6)
                }
            }
            .frame(height: CGFloat(totalDuration) * pixelsPerSecond)
        }
        .frame(height: CGFloat(totalDuration) * pixelsPerSecond)
    }

    private var timeMarks: [TimeInterval] {
        // Адаптивный интервал: для коротких файлов 5 секунд, для длинных 10
        let interval: TimeInterval = totalDuration < 60 ? 5 : 10
        var marks: [TimeInterval] = [0]
        var current = interval
        while current <= totalDuration {
            marks.append(current)
            current += interval
        }
        return marks
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Колонка для одного спикера
struct SpeakerColumn: View {
    let turns: [DialogueTranscription.Turn]
    let speaker: DialogueTranscription.Turn.Speaker
    let totalDuration: TimeInterval
    let pixelsPerSecond: CGFloat
    @ObservedObject var audioPlayer: AudioPlayerManager

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Фон колонки
                RoundedRectangle(cornerRadius: 8)
                    .fill(speaker == .left ? Color.blue.opacity(0.05) : Color.orange.opacity(0.05))

                // Заголовок колонки
                VStack {
                    Text(speaker.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(speaker == .left ? .blue : .orange)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.8))

                    Spacer()
                }

                // Реплики, расположенные по времени (диалог уже сжат, используем startTime напрямую)
                ForEach(turns) { turn in
                    TurnBlock(turn: turn, speaker: speaker, audioPlayer: audioPlayer)
                        .offset(y: CGFloat(turn.startTime) * pixelsPerSecond + 30) // +30 для заголовка
                        .padding(.horizontal, 8)
                }
            }
            .frame(height: CGFloat(totalDuration) * pixelsPerSecond + 30)
        }
        .frame(height: CGFloat(totalDuration) * pixelsPerSecond + 30)
    }
}

/// Блок с репликой на timeline
struct TurnBlock: View {
    let turn: DialogueTranscription.Turn
    let speaker: DialogueTranscription.Turn.Speaker
    @ObservedObject var audioPlayer: AudioPlayerManager

    @State private var isHovered = false

    var body: some View {
        // Текст реплики
        Text(turn.text)
            .font(.system(size: 11))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(blockColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(borderColor, lineWidth: isHovered ? 2 : 1)
                    )
            )
            .onTapGesture {
                // Переход к времени реплики
                audioPlayer.seekAndPlay(to: turn.startTime)
                LogManager.app.info("Переход к реплике: \(turn.startTime)s")
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .help("Duration: \(String(format: "%.1f", turn.duration))s\nClick to play from this time")
    }

    private var blockColor: Color {
        if isHovered {
            return speaker == .left ? Color.blue.opacity(0.25) : Color.orange.opacity(0.25)
        } else {
            return speaker == .left ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15)
        }
    }

    private var borderColor: Color {
        if isHovered {
            return speaker == .left ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8)
        } else {
            return speaker == .left ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
