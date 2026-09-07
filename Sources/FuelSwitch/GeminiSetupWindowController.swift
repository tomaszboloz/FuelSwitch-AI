import SwiftUI
import AppKit

/// Its own window, not an inline swap inside `MenuContentView` — "Connect
/// Gemini" is reachable from the floating HUD too, which has no popover to
/// swap content inside.
@MainActor
final class GeminiSetupWindowController: NSObject, NSWindowDelegate {
    static let shared = GeminiSetupWindowController()

    private var window: NSWindow?

    func show(model: AppModel) {
        NSApp.activate(ignoringOtherApps: true)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = GeminiSetupView(model: model, close: { [weak self] in
            self?.window?.close()
        })
        .frame(width: 420, height: 340)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "FuelSwitch AI - " + model.t(.geminiSetupTitle)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
