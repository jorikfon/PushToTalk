import SwiftUI
import AppKit

/// Расширенный SwiftUI view для настроек приложения
/// Включает: модели, горячие клавиши, история транскрипций
struct EnhancedSettingsView: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @ObservedObject var history = TranscriptionHistory.shared
    @ObservedObject var audioDeviceManager = AudioDeviceManager.shared

    @State private var selectedTab: Tab = .models
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: String?
    @State private var showingExportSuccess = false
    @State private var isTestRecording = false

    enum Tab {
        case models, hotkeys, settings, history
    }

    var body: some View {
        ZStack {
            // Liquid Glass Background
            ZStack {
                // Основной blur
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Градиентный overlay для стеклянного эффекта
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)

                // Тонкая граница
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)

            // Content
            VStack(spacing: 0) {
                // Header
                headerView

                // Glass divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal)

                // Tab selector
                Picker("", selection: $selectedTab) {
                    Label("Models", systemImage: "cpu").tag(Tab.models)
                    Label("Hotkeys", systemImage: "keyboard").tag(Tab.hotkeys)
                    Label("Settings", systemImage: "gearshape").tag(Tab.settings)
                    Label("History", systemImage: "clock.fill").tag(Tab.history)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .models:
                        modelsView
                    case .hotkeys:
                        hotkeysView
                    case .settings:
                        settingsView
                    case .history:
                        historyView
                    }
                }

                // Glass divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal)

                // Footer
                footerView
            }
            .padding(20)
        }
        .frame(width: 500, height: 600)
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
            }
        } message: {
            Text("Are you sure you want to delete the \(modelToDelete ?? "") model? This action cannot be undone.")
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("History exported to Downloads folder")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Animated gradient icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.3),
                                Color.purple.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("PushToTalk Settings")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("AI Voice Assistant")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            // Recording indicator
            if controller.isRecording {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.red.opacity(0.4),
                                        Color.red.opacity(0.2),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 3,
                                    endRadius: 15
                                )
                            )
                            .frame(width: 30, height: 30)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }

                    Text("Recording")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Models View

    private var modelsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Download error alert
                if let error = modelManager.downloadError {
                    GroupBox {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Dismiss") {
                                modelManager.downloadError = nil
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                        .padding(8)
                    }
                }

                // Current model info
                GroupBox(label: Label("Active Model", systemImage: "checkmark.circle.fill").foregroundColor(.green)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(modelManager.currentModel.uppercased())
                                .font(.headline)
                            if let info = modelManager.getModelInfo(modelManager.currentModel) {
                                Text("\(info.speed) • \(info.accuracy) accuracy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(modelManager.getModelSize(modelManager.currentModel))
                            .font(.caption)
                            .padding(6)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(8)
                }

                // Available models
                Text("Available Models")
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(modelManager.supportedModels) { model in
                    modelRow(for: model)
                }
            }
            .padding()
        }
    }

    private func modelRow(for model: WhisperModel) -> some View {
        let isDownloaded = modelManager.downloadedModels.contains(model.name)
        let isActive = modelManager.currentModel == model.name
        let isDownloadingThisModel = modelManager.downloadingModel == model.name
        let canDownload = !modelManager.isDownloading || isDownloadingThisModel

        return GroupBox {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Model info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Size: \(model.size) • Speed: \(model.speed)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text("Accuracy: \(model.accuracy)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Actions
                    VStack(spacing: 4) {
                        if isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if isDownloaded {
                            Button("Use") {
                                modelManager.saveCurrentModel(model.name)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button(isDownloadingThisModel ? "Downloading..." : "Download") {
                                downloadModel(model.name)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!canDownload)
                        }

                        if isDownloaded && !isActive {
                            Button("Delete") {
                                modelToDelete = model.name
                                showingDeleteAlert = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                    }
                }

                // Progress bar for this specific model
                if isDownloadingThisModel {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: modelManager.downloadProgress, total: 1.0)
                            .progressViewStyle(.linear)

                        Text("Downloading \(model.displayName)... \(Int(modelManager.downloadProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Hotkeys View

    private var hotkeysView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // F-Key Selector (F13-F19)
                GroupBox(label: Label("Hotkey Selection", systemImage: "keyboard.badge.ellipsis").foregroundColor(.purple)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Выберите функциональную клавишу:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Hotkey", selection: Binding(
                            get: { hotkeyManager.currentHotkey.keyCode },
                            set: { newKeyCode in
                                let fKeyMap: [UInt16: String] = [
                                    105: "F13",
                                    107: "F14",
                                    113: "F15",
                                    106: "F16",
                                    64: "F17",
                                    79: "F18",
                                    80: "F19"
                                ]
                                if let name = fKeyMap[newKeyCode] {
                                    let newHotkey = Hotkey(
                                        name: name,
                                        keyCode: newKeyCode,
                                        displayName: name,
                                        modifiers: []
                                    )
                                    hotkeyManager.saveHotkey(newHotkey)
                                }
                            }
                        )) {
                            Text("F13").tag(UInt16(105))
                            Text("F14").tag(UInt16(107))
                            Text("F15").tag(UInt16(113))
                            Text("F16 (Default)").tag(UInt16(106))
                            Text("F17").tag(UInt16(64))
                            Text("F18").tag(UInt16(79))
                            Text("F19").tag(UInt16(80))
                        }
                        .pickerStyle(.menu)

                        Text("💡 F13-F19 не требуют Accessibility разрешения")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(8)
                }

                Divider()

                // Current hotkey
                GroupBox(label: Label("Active Hotkey", systemImage: "keyboard").foregroundColor(.blue)) {
                    HStack {
                        Text(hotkeyManager.currentHotkey.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(8)
                }

                Divider()
                    .padding(.vertical, 8)

                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Label("Press and hold the hotkey to start recording", systemImage: "hand.tap")
                        .font(.caption)
                    Label("Release the hotkey to transcribe", systemImage: "text.bubble")
                        .font(.caption)
                    Label("Text will be inserted at cursor position", systemImage: "character.cursor.ibeam")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .padding()
        }
    }


    // MARK: - Settings View

    @State private var newStopWord: String = ""

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Stop Words Section
                GroupBox(label: Label("Stop Words", systemImage: "hand.raised.fill").foregroundColor(.orange)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Слова, при распознавании которых транскрипция будет отменена")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Add new stop word
                        HStack {
                            TextField("Добавить стоп-слово...", text: $newStopWord)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addNewStopWord()
                                }

                            Button(action: addNewStopWord) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)
                            .disabled(newStopWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        // Current stop words
                        if UserSettings.shared.stopWords.isEmpty {
                            Text("Нет стоп-слов")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(UserSettings.shared.stopWords, id: \.self) { word in
                                HStack {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)

                                    Text(word)
                                        .font(.body)

                                    Spacer()

                                    Button(action: {
                                        UserSettings.shared.removeStopWord(word)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(8)
                }

                Divider()

                // Recording Settings
                GroupBox(label: Label("Recording Settings", systemImage: "timer").foregroundColor(.purple)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Максимальная длительность записи (секунды)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            TextField("60", value: Binding(
                                get: { Int(UserSettings.shared.maxRecordingDuration) },
                                set: { UserSettings.shared.maxRecordingDuration = TimeInterval(max(10, min(300, $0))) }
                            ), formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)

                            Text("Диапазон: 10-300 секунд. Запись остановится автоматически.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }

                Divider()

                // Audio Device Selection
                GroupBox(label: Label("Audio Input", systemImage: "mic.fill").foregroundColor(.green)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Выбор микрофона")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !audioDeviceManager.availableDevices.isEmpty {
                            Picker("Микрофон", selection: Binding(
                                get: {
                                    if let selected = audioDeviceManager.selectedDevice {
                                        return selected
                                    }
                                    return audioDeviceManager.availableDevices.first!
                                },
                                set: { device in
                                    audioDeviceManager.saveSelectedDevice(device)
                                }
                            )) {
                                ForEach(audioDeviceManager.availableDevices) { device in
                                    Text(device.displayName).tag(device)
                                }
                            }
                            .labelsHidden()
                        } else {
                            Text("Нет доступных устройств")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        Button("Обновить список устройств") {
                            audioDeviceManager.scanAvailableDevices()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(8)
                }

                Divider()

                // Audio Settings
                GroupBox(label: Label("Audio Settings", systemImage: "speaker.wave.3").foregroundColor(.blue)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Повышать громкость микрофона при записи", isOn: Binding(
                            get: { MicrophoneVolumeManager.shared.volumeBoostEnabled },
                            set: { MicrophoneVolumeManager.shared.saveVolumeBoostEnabled($0) }
                        ))

                        Toggle("Приглушать системный звук при записи", isOn: Binding(
                            get: { AudioDuckingManager.shared.duckingEnabled },
                            set: { AudioDuckingManager.shared.saveDuckingEnabled($0) }
                        ))

                        if AudioDuckingManager.shared.duckingEnabled {
                            Toggle("Полностью выключать звук (вместо приглушения)", isOn: Binding(
                                get: { AudioDuckingManager.shared.muteOutputCompletely },
                                set: { AudioDuckingManager.shared.saveMuteOutputCompletely($0) }
                            ))
                            .padding(.leading, 20)
                        }
                    }
                    .padding(8)
                }
            }
            .padding()
        }
    }

    private func addNewStopWord() {
        let trimmed = newStopWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        UserSettings.shared.addStopWord(trimmed)
        newStopWord = ""
    }

    // MARK: - History View

    private var historyView: some View {
        VStack(spacing: 0) {
            // Statistics
            let stats = history.statistics

            GroupBox {
                HStack(spacing: 20) {
                    statItem(title: "Total", value: "\(stats.totalTranscriptions)")
                    Divider()
                    statItem(title: "Words", value: "\(stats.totalWords)")
                    Divider()
                    statItem(title: "Avg Time", value: stats.formattedAverageDuration)
                }
                .frame(height: 40)
            }
            .padding()

            // History list
            if history.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No transcriptions yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Press and hold the hotkey to start recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(history.history) { entry in
                            historyRow(for: entry)
                        }
                    }
                    .padding()
                }
            }

            // History controls
            Divider()
            HStack(spacing: 12) {
                // Test recording button
                Button(action: {
                    testRecording()
                }) {
                    Label(isTestRecording ? "Recording..." : "Test Recording",
                          systemImage: isTestRecording ? "mic.fill" : "mic")
                }
                .buttonStyle(.borderedProminent)
                .tint(isTestRecording ? .red : .blue)
                .disabled(isTestRecording)

                if !history.history.isEmpty {
                    Button(action: {
                        if history.exportToFile() != nil {
                            showingExportSuccess = true
                        }
                    }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if !history.history.isEmpty {
                    Button(action: {
                        history.clearHistory()
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func historyRow(for entry: TranscriptionEntry) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(entry.relativeTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(String(format: "%.1fs", entry.duration))
                        .font(.caption2)
                        .padding(4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)

                    Text("\(entry.wordCount) words")
                        .font(.caption2)
                        .padding(4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }

                // Text
                Text(entry.text)
                    .font(.body)
                    .lineLimit(3)

                // Actions
                HStack(spacing: 8) {
                    Button(action: {
                        history.copyToClipboard(entry)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    Button(action: {
                        history.deleteEntry(entry)
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .frame(width: 80)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Spacer()

            Text("PushToTalk v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Actions

    private func downloadModel(_ modelName: String) {
        Task {
            do {
                try await modelManager.downloadModel(modelName)
            } catch {
                print("Error downloading model: \(error)")
            }
        }
    }

    private func deleteModel(_ modelName: String) {
        do {
            try modelManager.deleteModel(modelName)
        } catch {
            print("Error deleting model: \(error)")
        }
    }

    private func testRecording() {
        isTestRecording = true
        print("🎤 TEST RECORDING: Starting 3-second test recording...")

        // Send notification to start recording
        NotificationCenter.default.post(name: NSNotification.Name("StartTestRecording"), object: nil)

        // Stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🎤 TEST RECORDING: Stopping and transcribing...")
            NotificationCenter.default.post(name: NSNotification.Name("StopTestRecording"), object: nil)
            isTestRecording = false
        }
    }
}
