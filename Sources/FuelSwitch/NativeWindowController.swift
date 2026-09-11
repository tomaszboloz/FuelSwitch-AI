import AppKit
import SwiftUI

@MainActor
final class NativeWindowController: NSObject, NSWindowDelegate {
    static let shared = NativeWindowController()
    private var window: NSWindow?

    func show(model: AppModel) {
        NSApp.activate(ignoringOtherApps: true)
        if let window { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "FuelSwitch AI"
        window.contentMinSize = NSSize(width: 800, height: 600)
        window.collectionBehavior = [.fullScreenPrimary]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: NativeTemplateView(model: model))
        window.center()
        window.setFrameAutosaveName("FuelSwitch_NativeWorkspace")
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
    func windowWillClose(_ notification: Notification) { window = nil }
}
