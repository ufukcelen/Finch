import SwiftUI
import AppKit

@MainActor
public final class DesktopWindowManager: NSObject {
    public static let shared = DesktopWindowManager()

    private var settingsWindow: NSWindow?

    override private init() {
        super.init()
    }

    public func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 490),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "YouTube Widget Ayarları"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: WidgetViewModel.shared))

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeSettingsWindow() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}
