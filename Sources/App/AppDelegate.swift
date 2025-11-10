import Cocoa
import PushToTalkCore

/// Главный делегат приложения
/// Отвечает исключительно за lifecycle приложения
/// Вся бизнес-логика делегируется AppCoordinator
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Dependencies

    /// Service container для dependency injection
    private let container = ServiceContainer.shared

    /// Главный координатор приложения
    private var appCoordinator: AppCoordinator?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Starting ===")

        // Устанавливаем .accessory - приложение всегда скрыто из Dock
        NSApp.setActivationPolicy(.accessory)
        LogManager.app.info("Activation policy: .accessory (menu bar only)")

        // Инициализация главного координатора
        appCoordinator = AppCoordinator(container: container)

        // Асинхронный запуск приложения
        Task {
            await appCoordinator?.start()
        }
    }

    /// Предотвращаем автоматическое завершение приложения при закрытии последнего окна
    /// Приложение должно работать пока пользователь не выберет Quit из menu bar
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // НЕ завершаем приложение при закрытии окон
    }

    func applicationWillTerminate(_ notification: Notification) {
        LogManager.app.info("=== PushToTalk Terminating ===")

        // Остановка приложения через координатор
        appCoordinator?.stop()

        LogManager.app.info("=== Cleanup завершен ===")
    }
}
