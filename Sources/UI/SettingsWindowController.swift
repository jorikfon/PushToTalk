import Cocoa
import SwiftUI

/// Контроллер отдельного окна настроек (не popover)
/// Показывается при выборе "Настройки" в меню
class SettingsWindowController: NSWindowController {

    private var settingsWindow: NSWindow?
    private weak var menuBarController: MenuBarController?

    init(menuBarController: MenuBarController) {
        self.menuBarController = menuBarController
        // Создаем окно настроек с увеличенным размером для нового дизайна
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "PushToTalk - Настройки"
        window.center()
        window.isReleasedWhenClosed = false

        // Устанавливаем минимальный размер окна
        window.minSize = NSSize(width: 800, height: 600)

        self.settingsWindow = window

        super.init(window: window)

        setupContent()

        LogManager.app.info("SettingsWindowController: Инициализирован")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Настройка содержимого окна
    private func setupContent() {
        guard let window = settingsWindow,
              let controller = menuBarController else { return }

        // Создаем hosting controller с ModernSettingsView (новый дизайн)
        let settingsView = ModernSettingsView(controller: controller)
        let hostingController = NSHostingController(rootView: settingsView)

        window.contentViewController = hostingController

        LogManager.app.debug("SettingsWindowController: Контент настроен")
    }

    /// Показать окно настроек
    func showSettings() {
        guard let window = settingsWindow else { return }

        // Если окно уже показано, просто активируем его
        if window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            LogManager.app.debug("SettingsWindowController: Окно уже открыто, активируем")
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            LogManager.app.info("SettingsWindowController: Окно показано")
        }
    }

    /// Скрыть окно настроек
    func hideSettings() {
        settingsWindow?.close()
        LogManager.app.info("SettingsWindowController: Окно скрыто")
    }

    /// Проверка, открыто ли окно
    var isVisible: Bool {
        return settingsWindow?.isVisible ?? false
    }
}
