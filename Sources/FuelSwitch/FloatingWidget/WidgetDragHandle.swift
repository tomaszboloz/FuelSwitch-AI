import AppKit
import SwiftUI

/// A small AppKit-owned hit target that starts a real window drag.
///
/// `isMovableByWindowBackground` alone is not reliable for SwiftUI-hosted
/// borderless-looking panels on newer macOS releases: the hosting view consumes
/// the mouse-down before AppKit can initiate the background move. Put this over
/// a non-interactive logo/handle so the widget always has a native drag target.
struct WidgetDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragSurface()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragSurface: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
