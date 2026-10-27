import SwiftUI
import AppKit

@MainActor
public final class DesktopWindowManager: NSObject, NSWindowDelegate {
    public static let shared = DesktopWindowManager()

    private var settingsWindow: NSWindow?

    override private init() {
        super.init()
    }

    public func openSettingsWindow(slot: String? = nil) {
        // Switch to regular activation policy so window is an active GUI app
        NSApp.setActivationPolicy(.regular)

        if let slot = slot {
            WidgetViewModel.shared.activeSlot = slot
        }

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Sosyal Medya Widget Ayarları & Yönetici"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView(viewModel: WidgetViewModel.shared))

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeSettingsWindow() {
        settingsWindow?.orderOut(nil)
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

    public func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
