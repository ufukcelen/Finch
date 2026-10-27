import SwiftUI
import AppKit

@main
struct YouTubeWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Sosyal Medya Widget Ayarları", id: "settings") {
            SettingsView(viewModel: WidgetViewModel.shared)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App launches without any MenuBarExtra icon
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow()
        }
        return true
    }
}
