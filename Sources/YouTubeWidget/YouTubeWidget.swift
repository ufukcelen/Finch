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
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "http" || url.scheme == "https" {
                // Widget was clicked -> Open the profile or content in default browser (Safari, Chrome, etc.)
                NSWorkspace.shared.open(url)
            } else if url.scheme == "youtubewidget" || url.scheme == "socialwidget" {
                // Settings URL scheme -> Open settings window
                let platformParam = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "platform" })?.value
                Task { @MainActor in
                    DesktopWindowManager.shared.openSettingsWindow(slot: platformParam)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Only open settings window if the user directly clicked the app icon in Finder/Dock and no window is open
        if !flag {
            Task { @MainActor in
                DesktopWindowManager.shared.openSettingsWindow(slot: nil)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in background so clicking widget gear button responds instantly
        return false
    }
}
