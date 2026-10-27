import SwiftUI
import AppKit

public struct WindowDragArea: NSViewRepresentable {
    private let showHandCursor: Bool

    public init(showHandCursor: Bool = false) {
        self.showHandCursor = showHandCursor
    }

    public func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.showHandCursor = showHandCursor
        return view
    }

    public func updateNSView(_ nsView: DragView, context: Context) {
        nsView.showHandCursor = showHandCursor
    }

    public final class DragView: NSView {
        var showHandCursor: Bool = false

        override public func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
            DispatchQueue.main.async {
                DesktopWindowManager.shared.snapWindowToGrid()
            }
        }

        override public func resetCursorRects() {
            super.resetCursorRects()
            if showHandCursor {
                addCursorRect(bounds, cursor: .openHand)
            }
        }
    }
}
