import AppKit
import SwiftUI

/// An AppKit-owned hit target that starts a real window drag.
///
/// `isMovableByWindowBackground` alone is not reliable for SwiftUI-hosted
/// borderless-looking panels on newer macOS releases: the hosting view consumes
/// the mouse-down before AppKit can initiate the background move. Use this as a
/// full-size background (behind controls) and over the logo as a reliable handle.
struct WidgetDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WidgetDragSurface()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WidgetDragSurface: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
