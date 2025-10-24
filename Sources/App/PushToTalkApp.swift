import SwiftUI

/// Главная точка входа приложения
@main
struct PushToTalkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar приложение без основного окна
        Settings {
            EmptyView()
        }
    }
}
