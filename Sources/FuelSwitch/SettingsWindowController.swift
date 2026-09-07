import SwiftUI
import AppKit

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(model: AppModel) {
        NSApp.activate(ignoringOtherApps: true)

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = SettingsView(model: model, close: { [weak self] in
            self?.window?.close()
        })
        .frame(width: 580, height: 560)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "FuelSwitch AI - " + model.t(.settings)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.contentView = NSHostingView(rootView: contentView)
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
