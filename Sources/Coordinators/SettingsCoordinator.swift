import Foundation
import Cocoa
import SwiftUI
import PushToTalkCore

/// Координатор для управления окном настроек и синхронизацией изменений
///
/// Отвечает за:
/// - Открытие/закрытие окна настроек
/// - Создание и конфигурацию окна настроек
/// - Передачу зависимостей в Views через Environment
/// - Координацию изменений настроек между UI и менеджерами
/// - Перезагрузку модели WhisperService при изменении
public final class SettingsCoordinator: NSObject {
    // MARK: - Dependencies

    private let whisperService: WhisperServiceProtocol
    private let modelManager: ModelManagerProtocol
    private let audioDeviceManager: AudioDeviceManagerProtocol
    private let vocabularyManager: VocabularyManagerProtocol
    private let hotkeyManager: HotkeyManagerProtocol
    private let keyboardMonitor: KeyboardMonitorProtocol
    private let menuBarController: MenuBarController
    private let userSettings: UserSettings

    // MARK: - State

    /// Окно настроек
    private var settingsWindow: NSWindow?

    /// Callback для уведомления о изменении модели (вызывается из UI)
    public var onModelChanged: ((String) async throws -> Void)?

    // MARK: - Initialization

    public init(
        whisperService: WhisperServiceProtocol,
        modelManager: ModelManagerProtocol,
        audioDeviceManager: AudioDeviceManagerProtocol,
        vocabularyManager: VocabularyManagerProtocol,
        hotkeyManager: HotkeyManagerProtocol,
        keyboardMonitor: KeyboardMonitorProtocol,
        menuBarController: MenuBarController,
        userSettings: UserSettings = .shared
    ) {
        self.whisperService = whisperService
        self.modelManager = modelManager
        self.audioDeviceManager = audioDeviceManager
        self.vocabularyManager = vocabularyManager
        self.hotkeyManager = hotkeyManager
        self.keyboardMonitor = keyboardMonitor
        self.menuBarController = menuBarController
        self.userSettings = userSettings
    }

    // MARK: - Public API

    /// Открыть окно настроек (или вывести на передний план если уже открыто)
    public func showSettings() {
        if let window = settingsWindow {
            // Окно уже существует - выводим на передний план
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Создаём новое окно
            settingsWindow = createSettingsWindow()
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Закрыть окно настроек
    public func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }

    // MARK: - Private Methods

    /// Создание окна настроек с конфигурацией
    private func createSettingsWindow() -> NSWindow {
        // TODO: Когда будут ViewModels, создаём contentView с ними
        // Сейчас передаём menuBarController который требуется для ModernSettingsView
        let contentView = ModernSettingsView(controller: menuBarController)

        // Создание окна
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: UIConstants.Window.settingsWindowWidth,
                height: UIConstants.Window.settingsWindowHeight
            ),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Конфигурация окна
        window.title = Strings.App.settings
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: contentView)

        // Установка минимального размера
        window.minSize = NSSize(
            width: UIConstants.Window.settingsWindowMinWidth,
            height: UIConstants.Window.settingsWindowMinHeight
        )

        // Делегат для обработки закрытия
        window.delegate = self

        return window
    }

    /// Обработка изменения модели из UI
    private func handleModelChange(_ newModelSize: String) {
        LogManager.app.info("SettingsCoordinator: Запрос на смену модели на \(newModelSize)")

        Task {
            do {
                // Вызываем callback для перезагрузки модели
                try await onModelChanged?(newModelSize)
                LogManager.app.success("SettingsCoordinator: Модель успешно изменена на \(newModelSize)")
            } catch {
                LogManager.app.failure("SettingsCoordinator: Смена модели", error: error)
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension SettingsCoordinator: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        LogManager.app.info("Settings window закрывается")
        settingsWindow = nil
    }
}

// MARK: - Environment Key для callback

/// Environment key для передачи callback смены модели в SwiftUI Views
private struct ModelChangedCallbackKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    var modelChangedCallback: ((String) -> Void)? {
        get { self[ModelChangedCallbackKey.self] }
        set { self[ModelChangedCallbackKey.self] = newValue }
    }
}
