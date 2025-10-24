import SwiftUI
import AppKit

/// Контроллер menu bar приложения
/// Управляет иконкой в menu bar и popover с настройками
public class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    @Published public var isRecording = false
    @Published public var modelSize: String = "tiny"

    public init() {
        print("MenuBarController: Инициализация")
    }

    /// Настройка menu bar элемента
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon(recording: false)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Создаем popover для настроек
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 250)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: SettingsView(controller: self)
        )

        print("MenuBarController: ✓ Menu bar настроен")
    }

    /// Переключение отображения popover
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    /// Обновление иконки в зависимости от состояния записи
    public func updateIcon(recording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isRecording = recording

            if let button = self.statusItem?.button {
                // Меняем иконку в зависимости от состояния
                let iconName = recording ? "mic.fill" : "mic"
                button.image = NSImage(
                    systemSymbolName: iconName,
                    accessibilityDescription: recording ? "Recording" : "PushToTalk"
                )

                // Анимация при записи
                if recording {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.3
                        button.animator().alphaValue = 0.5
                    } completionHandler: {
                        NSAnimationContext.runAnimationGroup { context in
                            context.duration = 0.3
                            button.animator().alphaValue = 1.0
                        }
                    }
                }
            }
        }
    }

    /// Показ ошибки пользователю
    public func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "PushToTalk Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Показ информационного сообщения
    public func showInfo(_ title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
