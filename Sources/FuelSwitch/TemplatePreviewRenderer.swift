import AppKit
import SwiftUI
import FuelSwitchCore

/// Opt-in, offline render of production views with synthetic .example accounts.
/// Exits before the live model is constructed, avoiding credentials and polling.
@MainActor
enum TemplatePreviewRenderer {
    static func render(to directory: String) throws {
        let destination = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for template in InterfaceTemplate.allCases {
            for dark in [false, true] {
                let mode = dark ? "dark" : "light"
                let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
                let model = AppModel(preview: template)
                let main: AnyView = template == .native
                    ? AnyView(NativeTemplateView(model: model))
                    : AnyView(MenuContentView(model: model))
                try save(main, size: template == .native ? NSSize(width: 1200, height: 800) : NSSize(width: 700, height: 620),
                         appearance: appearance, to: destination.appendingPathComponent("\(template.rawValue)-main-\(mode).png"))
                for compact in [false, true] {
                    let widgetModel = AppModel(preview: template, previewWidgetStyle: compact ? "compact" : "expanded")
                    try save(AnyView(FloatingWidgetView(model: widgetModel, onClose: {})),
                             size: compact ? NSSize(width: 960, height: 70) : NSSize(width: 440, height: 400),
                             appearance: appearance,
                             to: destination.appendingPathComponent("\(template.rawValue)-widget-\(compact ? "compact-bar" : "expanded")-\(mode).png"))
                }
            }
        }
    }

    private static func save(_ view: AnyView, size: NSSize, appearance: NSAppearance, to url: URL) throws {
        let host = NSHostingView(rootView: view)
        host.appearance = appearance
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // Allow native table/list layout to complete without presenting a window.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        var png: Data?
        appearance.performAsCurrentDrawingAppearance {
            if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                png = bitmap.representation(using: .png, properties: [:])
            }
        }
        guard let png else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url, options: .atomic)
        window.close()
    }
}
