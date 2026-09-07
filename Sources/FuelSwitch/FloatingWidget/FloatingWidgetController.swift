import SwiftUI
import AppKit
import FuelSwitchCore

@MainActor
final class FloatingWidgetController: NSObject, NSWindowDelegate {
    static let shared = FloatingWidgetController()

    private var panel: NSPanel?
    private var model: AppModel?
    private let expandedFrameKey = "FuelSwitch_FloatingWidget_ExpandedFrame"
    private let compactFrameKey = "FuelSwitch_FloatingWidget_CompactFrame"

    private var currentFrameKey: String {
        (model?.widgetStyle == "compact") ? compactFrameKey : expandedFrameKey
    }

    private override init() {
        super.init()
    }

    func configure(with model: AppModel) {
        self.model = model
        if model.showFloatingWidget {
            showWidget()
        }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            showWidget()
        } else {
            hideWidget()
        }
    }

    func updateOpacity(_ opacity: Double) {
        panel?.alphaValue = CGFloat(opacity)
    }

    func updateAlwaysOnTop(_ alwaysOnTop: Bool) {
        panel?.level = alwaysOnTop ? .floating : .normal
    }

    func updateStyle() {
        guard let model, let panel else { return }
        let isCompact = model.widgetStyle == "compact"
        let current = panel.frame

        if isCompact {
            // Save expanded frame before shrinking
            UserDefaults.standard.set(NSStringFromRect(current), forKey: expandedFrameKey)

            // A pill presents both 5h and weekly fuel for every connected
            // provider.  Keep a full single row available so the values are
            // never clipped when Claude, Codex and Gemini are all connected.
            panel.minSize = NSSize(width: 580, height: 42)
            panel.maxSize = NSSize(width: 900, height: 70)

            var targetRect = NSRect(x: current.minX, y: current.maxY - 46, width: max(current.width, 660), height: 46)
            if let saved = UserDefaults.standard.string(forKey: compactFrameKey) {
                let r = NSRectFromString(saved)
                if r.width >= 580 && r.height >= 40 && r.height <= 70 {
                    targetRect = NSRect(x: current.minX, y: current.maxY - r.height, width: r.width, height: r.height)
                }
            }
            panel.setFrame(targetRect, display: true, animate: true)
        } else {
            // Save compact frame before expanding
            UserDefaults.standard.set(NSStringFromRect(current), forKey: compactFrameKey)

            panel.minSize = NSSize(width: 260, height: 160)
            panel.maxSize = NSSize(width: 900, height: 900)

            var targetRect = NSRect(x: current.minX, y: current.maxY - 320, width: max(current.width, 340), height: 320)
            if let saved = UserDefaults.standard.string(forKey: expandedFrameKey) {
                let r = NSRectFromString(saved)
                if r.width >= 260 && r.height >= 160 {
                    targetRect = NSRect(x: current.minX, y: current.maxY - r.height, width: r.width, height: r.height)
                }
            }
            panel.setFrame(targetRect, display: true, animate: true)
        }
    }

    private func showWidget() {
        guard let model else { return }

        if let existing = panel {
            existing.orderFront(nil)
            return
        }

        let isCompact = model.widgetStyle == "compact"
        let defaultRect = isCompact
            ? NSRect(x: 120, y: 150, width: 660, height: 46)
            : NSRect(x: 120, y: 150, width: 340, height: 340)
        var initialRect = defaultRect

        let saveKey = isCompact ? compactFrameKey : expandedFrameKey
        if let savedString = UserDefaults.standard.string(forKey: saveKey) {
            let savedRect = NSRectFromString(savedString)
            if isCompact {
                if savedRect.width >= 580 && savedRect.height >= 40 && savedRect.height <= 70 {
                    initialRect = savedRect
                }
            } else {
                if savedRect.width >= 260 && savedRect.height >= 160 {
                    initialRect = savedRect
                }
            }
        }

        let newPanel = NSPanel(
            contentRect: initialRect,
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true
        newPanel.showsResizeIndicator = true

        newPanel.isFloatingPanel = true
        newPanel.level = model.widgetAlwaysOnTop ? .floating : .normal
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.alphaValue = CGFloat(model.widgetOpacity)
        newPanel.delegate = self
        newPanel.minSize = isCompact ? NSSize(width: 580, height: 42) : NSSize(width: 260, height: 160)
        newPanel.maxSize = isCompact ? NSSize(width: 900, height: 70) : NSSize(width: 900, height: 900)

        let contentView = FloatingWidgetView(model: model, onClose: { [weak self] in
            model.showFloatingWidget = false
            self?.hideWidget()
        })

        newPanel.contentView = NSHostingView(rootView: contentView)
        newPanel.orderFront(nil)
        self.panel = newPanel
    }

    private func hideWidget() {
        if let panel {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: currentFrameKey)
            panel.orderOut(nil)
            self.panel = nil
        }
    }

    public func windowDidMove(_ notification: Notification) {
        if let panel {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: currentFrameKey)
        }
    }

    public func windowDidResize(_ notification: Notification) {
        if let panel {
            UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: currentFrameKey)
        }
    }
}
