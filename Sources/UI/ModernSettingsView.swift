import SwiftUI
import AppKit

/// Современное окно настроек с боковым меню и Liquid Glass эффектом
struct ModernSettingsView: View {
    @ObservedObject var controller: MenuBarController
    @ObservedObject var modelManager = ModelManager.shared
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    @ObservedObject var history = TranscriptionHistory.shared
    @ObservedObject var audioDeviceManager = AudioDeviceManager.shared
    @ObservedObject var userSettings = UserSettings.shared
    @ObservedObject var audioDuckingManager = AudioDuckingManager.shared
    @ObservedObject var micVolumeManager = MicrophoneVolumeManager.shared

    @State private var selectedSection: SettingsSection = .general
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: String?
    @State private var showingExportSuccess = false
    @State private var isTestRecording = false

    enum SettingsSection: String, CaseIterable, Identifiable {
        case debug = "Debug"
        case general = "General"
        case models = "Models"
        case hotkeys = "Hotkeys"
        case vocabulary = "Vocabulary"
        case audio = "Audio"
        case history = "History"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .debug: return "ladybug.fill"
            case .general: return "gearshape.fill"
            case .models: return "cpu"
            case .hotkeys: return "keyboard.fill"
            case .vocabulary: return "book.fill"
            case .audio: return "speaker.wave.3.fill"
            case .history: return "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .debug: return .red
            case .general: return .blue
            case .models: return .purple
            case .hotkeys: return .orange
            case .vocabulary: return .green
            case .audio: return .pink
            case .history: return .cyan
            }
        }
    }

    var body: some View {
        ZStack {
            // Liquid Glass Background
            ZStack {
                // Основной blur
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

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

            // Content with Sidebar
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                    .frame(width: 220)

                // Vertical Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1)

                // Content Area
                contentView
            }
            .padding(20)
        }
        .frame(width: 900, height: 650)
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

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
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
                        Text("PushToTalk")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("Settings")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)

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

            // Navigation Items
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarButton(section)
                    }
                }
                .padding(.vertical, 12)
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
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

                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    if selectedSection == section {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(section.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                    }

                    Image(systemName: section.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedSection == section ? section.color : .secondary)
                        .frame(width: 36, height: 36)
                }

                Text(section.rawValue)
                    .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                    .foregroundColor(selectedSection == section ? .primary : .secondary)

                Spacer()

                if selectedSection == section {
                    Rectangle()
                        .fill(section.color)
                        .frame(width: 3, height: 24)
                        .cornerRadius(1.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedSection == section ? Color.primary.opacity(0.05) : Color.clear)
            )
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: selectedSection.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(selectedSection.color)

                Text(selectedSection.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

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
                .padding(.horizontal, 24)

            // Section Content
            ScrollView {
                Group {
                    switch selectedSection {
                    case .debug:
                        debugView
                    case .general:
                        generalView
                    case .models:
                        modelsView
                    case .hotkeys:
                        hotkeysView
                    case .vocabulary:
                        vocabularyView
                    case .audio:
                        audioView
                    case .history:
                        historyView
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Section Views

    private var generalView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // File Transcription Settings
            settingsCard(title: "File Transcription", icon: "waveform", color: .green) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Настройки для транскрипции аудио/видео файлов")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Режим транскрипции
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Режим транскрипции")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("", selection: $userSettings.fileTranscriptionMode) {
                            ForEach(UserSettings.FileTranscriptionMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(userSettings.fileTranscriptionMode.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // VAD алгоритм (только для VAD режима)
                    if userSettings.fileTranscriptionMode == .vad {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VAD Алгоритм")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("", selection: $userSettings.vadAlgorithmType) {
                                ForEach(UserSettings.VADAlgorithmType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .pickerStyle(.menu)

                            Text(userSettings.vadAlgorithmType.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }

            // Stop Words Section
            settingsCard(title: "Stop Words", icon: "hand.raised.fill", color: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Слова, при распознавании которых транскрипция будет отменена")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    stopWordsSection
                }
            }

            // Recording Settings
            settingsCard(title: "Recording Settings", icon: "timer", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Максимальная длительность записи (секунды)")
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        TextField("60", value: Binding(
                            get: { Int(userSettings.maxRecordingDuration) },
                            set: { userSettings.maxRecordingDuration = TimeInterval(max(10, min(300, $0))) }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
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
            }
        }
    }

    private var modelsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Download error alert
            if let error = modelManager.downloadError {
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
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }

            // Current model info
            settingsCard(title: "Active Model", icon: "checkmark.circle.fill", color: .green) {
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
            }

            // Available models
            Text("Available Models")
                .font(.headline)
                .padding(.top, 8)

            ForEach(modelManager.supportedModels) { model in
                modelRow(for: model)
            }
        }
    }

    private func modelRow(for model: WhisperModel) -> some View {
        let isDownloaded = modelManager.downloadedModels.contains(model.name)
        let isActive = modelManager.currentModel == model.name
        let isDownloadingThisModel = modelManager.downloadingModel == model.name
        let canDownload = !modelManager.isDownloading || isDownloadingThisModel

        return VStack(spacing: 8) {
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
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private var hotkeysView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // F-Key Selector
            settingsCard(title: "Hotkey Selection", icon: "keyboard.badge.ellipsis", color: .purple) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите функциональную клавишу:")
                        .font(.subheadline)
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

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.green)
                        Text("F13-F19 не требуют Accessibility разрешения")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Current hotkey display
            settingsCard(title: "Active Hotkey", icon: "keyboard.fill", color: .blue) {
                HStack {
                    Text(hotkeyManager.currentHotkey.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }

            // Instructions
            settingsCard(title: "How to Use", icon: "questionmark.circle", color: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(icon: "hand.tap", text: "Press and hold the hotkey to start recording")
                    instructionRow(icon: "text.bubble", text: "Release the hotkey to transcribe")
                    instructionRow(icon: "character.cursor.ibeam", text: "Text will be inserted at cursor position")
                }
            }
        }
    }

    private var vocabularyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Custom Vocabularies Section
            settingsCard(title: "Custom Vocabularies", icon: "book.closed.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выберите словари для улучшения распознавания специфичных терминов")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    vocabularyListSection
                }
            }

            // Add New Vocabulary
            settingsCard(title: "Add New Vocabulary", icon: "plus.circle.fill", color: .blue) {
                addVocabularySection
            }

            // Vocabulary Help
            settingsCard(title: "About Vocabularies", icon: "info.circle", color: .cyan) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Словари помогают Whisper лучше распознавать специфичные термины, имена, бренды и техническую лексику.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Каждый словарь содержит список слов, которые будут приоритезированы при транскрипции.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var audioView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Audio Device Selection
            settingsCard(title: "Audio Input", icon: "mic.fill", color: .green) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Выбор микрофона")
                        .font(.subheadline)
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
            }

            // Audio Settings
            settingsCard(title: "Audio Settings", icon: "speaker.wave.3", color: .pink) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Повышать громкость микрофона при записи", isOn: Binding(
                        get: { micVolumeManager.volumeBoostEnabled },
                        set: { micVolumeManager.saveVolumeBoostEnabled($0) }
                    ))

                    Toggle("Приглушать системный звук при записи", isOn: Binding(
                        get: { audioDuckingManager.duckingEnabled },
                        set: { audioDuckingManager.saveDuckingEnabled($0) }
                    ))

                    if audioDuckingManager.duckingEnabled {
                        Toggle("Полностью выключать звук (вместо приглушения)", isOn: Binding(
                            get: { audioDuckingManager.muteOutputCompletely },
                            set: { audioDuckingManager.saveMuteOutputCompletely($0) }
                        ))
                        .padding(.leading, 20)
                    }

                    Toggle("Ставить на паузу медиа-плееры при записи", isOn: Binding(
                        get: { audioDuckingManager.pauseMediaEnabled },
                        set: { audioDuckingManager.savePauseMediaEnabled($0) }
                    ))

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text("Автоматически ставит на паузу Spotify, Apple Music, YouTube и другие плееры")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var historyView: some View {
        VStack(spacing: 16) {
            // Statistics
            let stats = history.statistics

            HStack(spacing: 16) {
                statCard(title: "Total", value: "\(stats.totalTranscriptions)", color: .blue)
                statCard(title: "Words", value: "\(stats.totalWords)", color: .green)
                statCard(title: "Avg Time", value: stats.formattedAverageDuration, color: .orange)
            }

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
                }
            }

            // History controls
            HStack(spacing: 12) {
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
        }
    }

    // MARK: - Helper Views

    private func settingsCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .medium))

                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            content()
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }

    private func historyRow(for entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text(entry.text)
                .font(.body)
                .lineLimit(3)

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
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Stop Words Section

    @State private var newStopWord: String = ""

    private var stopWordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .disabled(newStopWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Current stop words
            if userSettings.stopWords.isEmpty {
                Text("Нет стоп-слов")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(userSettings.stopWords, id: \.self) { word in
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .foregroundColor(.orange)
                                .font(.caption)

                            Text(word)
                                .font(.body)

                            Spacer()

                            Button(action: {
                                userSettings.removeStopWord(word)
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
        }
    }

    // MARK: - Vocabulary Section

    @State private var newVocabularyName: String = ""
    @State private var newVocabularyWords: String = ""

    private var vocabularyListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if userSettings.vocabularies.isEmpty {
                Text("Нет добавленных словарей")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(userSettings.vocabularies) { vocab in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { userSettings.enabledVocabularies.contains(vocab.id) },
                            set: { isEnabled in
                                if isEnabled {
                                    userSettings.enableVocabulary(vocab.id)
                                } else {
                                    userSettings.disableVocabulary(vocab.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vocab.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(vocab.words.count) слов")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            userSettings.removeVocabulary(vocab.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var addVocabularySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Название словаря (например: Медицина, IT, Имена)", text: $newVocabularyName)
                .textFieldStyle(.roundedBorder)

            Text("Введите слова через запятую:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $newVocabularyWords)
                .frame(height: 80)
                .font(.body)
                .border(Color.secondary.opacity(0.3), width: 1)
                .cornerRadius(4)

            HStack {
                Spacer()

                Button("Добавить словарь") {
                    addVocabulary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newVocabularyName.isEmpty || newVocabularyWords.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func addNewStopWord() {
        let trimmed = newStopWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        userSettings.addStopWord(trimmed)
        newStopWord = ""
    }

    private func addVocabulary() {
        let name = newVocabularyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordsString = newVocabularyWords.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !wordsString.isEmpty else { return }

        // Разбиваем слова по запятой и очищаем
        let words = wordsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return }

        userSettings.addVocabulary(name: name, words: words)

        // Очищаем поля
        newVocabularyName = ""
        newVocabularyWords = ""

        LogManager.app.info("Добавлен новый словарь: \(name) с \(words.count) словами")
    }

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

        NotificationCenter.default.post(name: NSNotification.Name("StartTestRecording"), object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🎤 TEST RECORDING: Stopping and transcribing...")
            NotificationCenter.default.post(name: NSNotification.Name("StopTestRecording"), object: nil)
            isTestRecording = false
        }
    }

    // MARK: - Debug View

    private var debugView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MediaRemote Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("MediaRemote Controls")
                        .font(.headline)
                    Spacer()
                }

                Text("Управление внешними медиа-плеерами (Spotify, Apple Music, YouTube)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Sending PAUSE command...")
                        MediaRemoteManager.shared.pause()
                    }) {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        print("DEBUG: Sending RESUME command...")
                        MediaRemoteManager.shared.resume(force: true)
                    }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                Button(action: {
                    print("DEBUG: Sending TOGGLE PLAY/PAUSE command...")
                    MediaRemoteManager.shared.togglePlayPause()
                }) {
                    Label("Toggle Play/Pause", systemImage: "playpause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button(action: {
                    MediaRemoteManager.shared.getNowPlayingInfo { info in
                        if let info = info {
                            print("DEBUG: Now Playing Info:")
                            for (key, value) in info {
                                print("  \(key): \(value)")
                            }
                        } else {
                            print("DEBUG: No now playing info available")
                        }
                    }
                }) {
                    Label("Get Now Playing Info", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Audio Ducking Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.purple)
                        .font(.title2)
                    Text("Audio Ducking")
                        .font(.headline)
                    Spacer()
                }

                Text("Управление громкостью системного аудио")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Ducking audio...")
                        AudioDuckingManager.shared.duck(force: true)
                    }) {
                        Label("Duck", systemImage: "speaker.wave.1")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(action: {
                        print("DEBUG: Unducking audio...")
                        AudioDuckingManager.shared.unduck(force: true)
                    }) {
                        Label("Unduck", systemImage: "speaker.wave.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Microphone Volume Testing
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Microphone Volume")
                        .font(.headline)
                    Spacer()
                }

                Text("Управление громкостью микрофона")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: {
                        print("DEBUG: Boosting microphone volume...")
                        MicrophoneVolumeManager.shared.boostMicrophoneVolume()
                    }) {
                        Label("Boost", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button(action: {
                        print("DEBUG: Restoring microphone volume...")
                        MicrophoneVolumeManager.shared.restoreMicrophoneVolume()
                    }) {
                        Label("Restore", systemImage: "mic")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            Divider()

            // Logs Information
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                    Text("Logs")
                        .font(.headline)
                    Spacer()
                }

                Text("Для просмотра логов в реальном времени откройте Terminal:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("log stream --predicate 'subsystem == \"com.pushtotalk.app\"' --level debug")
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(4)

                Button(action: {
                    let command = "log stream --predicate 'subsystem == \"com.pushtotalk.app\"' --level debug"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    print("DEBUG: Log command copied to clipboard")
                }) {
                    Label("Copy Command", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}
