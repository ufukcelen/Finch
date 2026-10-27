import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS from killing the app in background (LSUIElement mode)
        ProcessInfo.processInfo.disableAutomaticTermination("Keep app alive for widget interactions")

        // Open settings window on initial launch (from Spotlight, Finder, etc.)
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow(slot: nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let slotParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "slot" })?.value
            Task { @MainActor in
                DesktopWindowManager.shared.openSettingsWindow(slot: slotParam)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            DesktopWindowManager.shared.openSettingsWindow(slot: nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in background so clicking widget gear button responds instantly
        return false
    }
}
