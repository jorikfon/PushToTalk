import SwiftUI
import AppKit

/// Современное окно настроек с боковым меню и Liquid Glass эффектом
struct ModernSettingsView: View {
    @ObservedObject var controller: MenuBarController

    // Dependencies через ServiceContainer (вместо deprecated .shared)
    private let container = ServiceContainer.shared
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var history: TranscriptionHistory
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @ObservedObject var userSettings: UserSettings
    @ObservedObject var audioDuckingManager: AudioDuckingManager
    @ObservedObject var micVolumeManager: MicrophoneVolumeManager

    // Инициализатор с DI
    init(controller: MenuBarController) {
        self.controller = controller
        let container = ServiceContainer.shared
        self.modelManager = container.modelManager as! ModelManager
        self.hotkeyManager = container.hotkeyManager as! HotkeyManager
        self.history = container.transcriptionHistory
        self.audioDeviceManager = container.audioDeviceManager as! AudioDeviceManager
        self.userSettings = container.userSettings
        self.audioDuckingManager = container.audioDuckingManager
        self.micVolumeManager = container.micVolumeManager
    }

    @State private var selectedSection: SettingsSection = .general
    @State private var showingDeleteAlert = false
    @State private var modelToDelete: String?

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
                        DebugSettingsView(controller: controller)
                    case .general:
                        GeneralSettingsView(userSettings: userSettings)
                    case .models:
                        ModelSettingsView(modelManager: modelManager, showingDeleteAlert: $showingDeleteAlert, modelToDelete: $modelToDelete)
                    case .hotkeys:
                        HotkeySettingsView(hotkeyManager: hotkeyManager)
                    case .vocabulary:
                        VocabularySettingsView(userSettings: userSettings)
                    case .audio:
                        AudioSettingsView(audioDeviceManager: audioDeviceManager, audioDuckingManager: audioDuckingManager, micVolumeManager: micVolumeManager, userSettings: userSettings)
                    case .history:
                        HistorySettingsView(history: history, userSettings: userSettings)
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Helper Methods

    private func deleteModel(_ modelName: String) {
        Task {
            do {
                try await modelManager.deleteModel(modelName)
            } catch {
                print("Error deleting model: \(error)")
            }
        }
    }
}
