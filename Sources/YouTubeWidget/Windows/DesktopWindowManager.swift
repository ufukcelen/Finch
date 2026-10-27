import SwiftUI
import AppKit

public final class DraggableWidgetPanel: NSPanel {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    override public func mouseDown(with event: NSEvent) {
        self.performDrag(with: event)
    }
}

@MainActor
public final class DesktopWindowManager: NSObject {
    public static let shared = DesktopWindowManager()

    public var widgetWindow: NSPanel?
    private var settingsWindow: NSWindow?

    override private init() {
        super.init()
    }

    public func setupDesktopWidget() {
        guard widgetWindow == nil else { return }

        let panel = DraggableWidgetPanel(
            contentRect: NSRect(x: 100, y: 100, width: 340, height: 268),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = "YouTube Widget"

        // Set initial frame from saved coordinates or top-right default
        if let savedX = UserDefaults.standard.object(forKey: "YTWidget_PosX") as? Double,
           let savedY = UserDefaults.standard.object(forKey: "YTWidget_PosY") as? Double {
            panel.setFrameOrigin(NSPoint(x: savedX, y: savedY))
        } else if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.maxX - 360
            let y = screenRect.maxY - 280
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Host SwiftUI DesktopWidgetView
        let hostingView = NSHostingView(rootView: DesktopWidgetView(viewModel: WidgetViewModel.shared))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView

        self.widgetWindow = panel

        // Register window move notification to save position
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Apply settings
        let vm = WidgetViewModel.shared
        updateWindowLevel(isAlwaysOnTop: vm.isAlwaysOnTop)
        updateWindowOpacity(vm.widgetOpacity)

        if vm.showDesktopWidget {
            panel.orderFront(nil)
        }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = widgetWindow else { return }
        let origin = window.frame.origin
        UserDefaults.standard.set(origin.x, forKey: "YTWidget_PosX")
        UserDefaults.standard.set(origin.y, forKey: "YTWidget_PosY")
    }

    public func updateWindowLevel(isAlwaysOnTop: Bool) {
        guard let window = widgetWindow else { return }
        // Use .floating when always on top, and .normal when off (so it never gets swallowed by wallpaper)
        window.level = isAlwaysOnTop ? .floating : .normal
    }

    public func updateWindowOpacity(_ opacity: Double) {
        guard let window = widgetWindow else { return }
        window.alphaValue = CGFloat(opacity)
    }

    public func setWindowVisibility(_ isVisible: Bool) {
        guard let window = widgetWindow else { return }
        if isVisible {
            window.orderFront(nil)
        } else {
            window.orderOut(nil)
        }
    }

    public func toggleVisibility() {
        guard let window = widgetWindow else { return }
        if window.isVisible {
            setWindowVisibility(false)
            WidgetViewModel.shared.showDesktopWidget = false
        } else {
            setWindowVisibility(true)
            WidgetViewModel.shared.showDesktopWidget = true
        }
    }

    public func openSettingsWindow() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 490),
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
