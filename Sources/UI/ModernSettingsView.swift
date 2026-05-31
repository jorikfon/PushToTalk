import SwiftUI
import AppKit

/// Окно настроек с боковым меню (Refined Native: vibrancy + один акцент)
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
            case .debug: return "ladybug"
            case .general: return "gearshape"
            case .models: return "cpu"
            case .hotkeys: return "keyboard"
            case .vocabulary: return "character.book.closed"
            case .audio: return "mic"
            case .history: return "clock"
            }
        }
    }

    var body: some View {
        ZStack {
            // Refined Native background: один материал, без белых оверлеев
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.Radius.window))
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.Radius.window)
                        .strokeBorder(UIConstants.Palette.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)

            // Content with Sidebar
            HStack(spacing: 0) {
                // Sidebar
                sidebarView
                    .frame(width: 200)

                // Вертикальный разделитель — волосяная линия
                Rectangle()
                    .fill(UIConstants.Palette.hairline)
                    .frame(width: 1)

                // Content Area
                contentView
            }
            .padding(UIConstants.Spacing.lg)
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
            // Header — брендовый знак (единственный акцентный градиент)
            VStack(alignment: .leading, spacing: UIConstants.Spacing.sm) {
                HStack(spacing: UIConstants.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    UIConstants.Palette.accent,
                                    UIConstants.Palette.accent.opacity(0.75)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: UIConstants.Palette.accent.opacity(0.4), radius: 4, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PushToTalk")
                            .font(UIConstants.Typography.headline)
                            .foregroundColor(.primary)

                        Text("Settings")
                            .font(UIConstants.Typography.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, UIConstants.Spacing.lg)
                .padding(.top, UIConstants.Spacing.sm)

                // Индикатор записи (семантический красный)
                if controller.isRecording {
                    HStack(spacing: UIConstants.Spacing.sm) {
                        Circle()
                            .fill(UIConstants.StateColors.recording)
                            .frame(width: 7, height: 7)
                            .shadow(color: UIConstants.StateColors.recording.opacity(0.6), radius: 4)

                        Text("Recording")
                            .font(UIConstants.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(UIConstants.StateColors.recording)
                    }
                    .padding(.horizontal, UIConstants.Spacing.md)
                    .padding(.vertical, UIConstants.Spacing.xs + 2)
                    .background(
                        Capsule()
                            .fill(UIConstants.StateColors.recording.opacity(0.12))
                    )
                    .padding(.horizontal, UIConstants.Spacing.lg)
                }
            }
            .padding(.bottom, UIConstants.Spacing.lg)

            // Разделитель
            Rectangle()
                .fill(UIConstants.Palette.hairline)
                .frame(height: 1)
                .padding(.horizontal, UIConstants.Spacing.md)

            // Навигация
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarButton(section)
                    }
                }
                .padding(.vertical, UIConstants.Spacing.sm)
                .padding(.horizontal, UIConstants.Spacing.sm)
            }

            Spacer()

            // Footer
            VStack(spacing: UIConstants.Spacing.sm) {
                Rectangle()
                    .fill(UIConstants.Palette.hairline)
                    .frame(height: 1)
                    .padding(.horizontal, UIConstants.Spacing.md)

                Text("v1.0")
                    .font(UIConstants.Typography.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, UIConstants.Spacing.sm)
            }
        }
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: UIConstants.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isSelected ? UIConstants.Palette.accent : .secondary)
                    .frame(width: 18)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? UIConstants.Palette.accent : .primary)

                Spacer()
            }
            .padding(.horizontal, UIConstants.Spacing.sm)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.Radius.control)
                    .fill(isSelected ? UIConstants.Palette.accentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок секции — крупный титул, без декоративной иконки
            Text(selectedSection.rawValue)
                .font(UIConstants.Typography.largeTitle)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UIConstants.Spacing.xl)
                .padding(.vertical, UIConstants.Spacing.lg)

            // Разделитель
            Rectangle()
                .fill(UIConstants.Palette.hairline)
                .frame(height: 1)
                .padding(.horizontal, UIConstants.Spacing.xl)

            // Контент секции
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
                .padding(UIConstants.Spacing.xl)
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
