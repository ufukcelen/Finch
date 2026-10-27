import SwiftUI
import AppKit

public final class DraggableWidgetPanel: NSPanel {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    override public func mouseDown(with event: NSEvent) {
        self.performDrag(with: event)
        // Automatically snap to desktop edges and grid when released
        DesktopWindowManager.shared.snapWindowToGrid()
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

        let vm = WidgetViewModel.shared
        let dimensions = vm.widgetSize.dimensions

        let panel = DraggableWidgetPanel(
            contentRect: NSRect(x: 100, y: 100, width: dimensions.width, height: dimensions.height),
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
            let x = screenRect.maxX - dimensions.width - 24
            let y = screenRect.maxY - dimensions.height - 24
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Host SwiftUI DesktopWidgetView
        let hostingView = NSHostingView(rootView: DesktopWidgetView(viewModel: WidgetViewModel.shared))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView

        self.widgetWindow = panel

        // Register window move notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Apply settings
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

    public func updateWindowSize(_ size: WidgetSize) {
        guard let window = widgetWindow else { return }
        let currentOrigin = window.frame.origin
        let currentHeight = window.frame.height
        let newDimensions = size.dimensions

        // Preserve top-left anchor point during resize
        let newY = currentOrigin.y + (currentHeight - newDimensions.height)
        let newFrame = NSRect(
            x: currentOrigin.x,
            y: newY,
            width: newDimensions.width,
            height: newDimensions.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }

        snapWindowToGrid()
    }

    /// Snaps the desktop widget magnetically to screen edges or grid columns
    public func snapWindowToGrid() {
        guard let window = widgetWindow, let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        let margin: CGFloat = 20.0
        let snapThreshold: CGFloat = 36.0

        var targetX = windowFrame.origin.x
        var targetY = windowFrame.origin.y

        // 1. Horizontal Edge & Grid Snapping
        let leftEdge = screenFrame.minX + margin
        let rightEdge = screenFrame.maxX - windowFrame.width - margin
        let centerX = screenFrame.midX - (windowFrame.width / 2)

        if abs(targetX - leftEdge) < snapThreshold {
            targetX = leftEdge
        } else if abs(targetX - rightEdge) < snapThreshold {
            targetX = rightEdge
        } else if abs(targetX - centerX) < snapThreshold {
            targetX = centerX
        } else {
            // Optional column grid snap (e.g. standard widget column spacing)
            let colStep: CGFloat = 190.0
            let colOffset = targetX - leftEdge
            let nearestCol = round(colOffset / colStep) * colStep + leftEdge
            if abs(targetX - nearestCol) < snapThreshold {
                targetX = nearestCol
            }
        }

        // 2. Vertical Edge & Grid Snapping
        let topEdge = screenFrame.maxY - windowFrame.height - margin
        let bottomEdge = screenFrame.minY + margin
        let centerY = screenFrame.midY - (windowFrame.height / 2)

        if abs(targetY - topEdge) < snapThreshold {
            targetY = topEdge
        } else if abs(targetY - bottomEdge) < snapThreshold {
            targetY = bottomEdge
        } else if abs(targetY - centerY) < snapThreshold {
            targetY = centerY
        } else {
            let rowStep: CGFloat = 190.0
            let rowOffset = targetY - bottomEdge
            let nearestRow = round(rowOffset / rowStep) * rowStep + bottomEdge
            if abs(targetY - nearestRow) < snapThreshold {
                targetY = nearestRow
            }
        }

        // Ensure within screen visible bounds
        targetX = max(screenFrame.minX, min(targetX, screenFrame.maxX - windowFrame.width))
        targetY = max(screenFrame.minY, min(targetY, screenFrame.maxY - windowFrame.height))

        let snappedFrame = NSRect(x: targetX, y: targetY, width: windowFrame.width, height: windowFrame.height)

        if snappedFrame.origin != windowFrame.origin {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(snappedFrame, display: true)
            }
        }

        UserDefaults.standard.set(targetX, forKey: "YTWidget_PosX")
        UserDefaults.standard.set(targetY, forKey: "YTWidget_PosY")
    }

    public func updateWindowLevel(isAlwaysOnTop: Bool) {
        guard let window = widgetWindow else { return }
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
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 530),
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
