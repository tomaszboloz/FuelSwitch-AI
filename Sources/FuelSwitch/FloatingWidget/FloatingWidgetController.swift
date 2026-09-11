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
        let base = (model?.widgetStyle == "compact") ? compactFrameKey : expandedFrameKey
        return model?.interfaceTemplate == .native ? base + "_Native" : base
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

        let bounds = FloatingWidgetLayout.bounds(forCompact: isCompact, template: model.interfaceTemplate)
        panel.minSize = bounds.minSize
        panel.maxSize = bounds.maxSize

        // Save the frame of the style we're leaving, so switching back restores it.
        let otherStyleKey = (isCompact ? expandedFrameKey : compactFrameKey) + (model.interfaceTemplate == .native ? "_Native" : "")
        UserDefaults.standard.set(NSStringFromRect(current), forKey: otherStyleKey)

        let savedFrame = UserDefaults.standard.string(forKey: currentFrameKey).map(NSRectFromString)
        let targetRect = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: isCompact, savedFrame: savedFrame)
        panel.setFrame(clamped(targetRect, bounds: bounds), display: true, animate: false)
    }

    func updateTemplate() {
        guard let panel, let model else { return }
        let bounds = FloatingWidgetLayout.bounds(forCompact: model.widgetStyle == "compact", template: model.interfaceTemplate)
        panel.minSize = bounds.minSize
        panel.maxSize = bounds.maxSize
        panel.setFrame(clamped(panel.frame, bounds: bounds), display: true)
    }

    private func clamped(_ rect: NSRect, bounds: FloatingWidgetLayout.Bounds) -> NSRect {
        let height = min(bounds.maxSize.height, max(bounds.minSize.height, rect.height))
        return NSRect(x: rect.minX, y: rect.maxY - height,
                      width: min(bounds.maxSize.width, max(bounds.minSize.width, rect.width)), height: height)
    }

    private func showWidget() {
        guard let model else { return }

        if let existing = panel {
            existing.orderFront(nil)
            return
        }

        let isCompact = model.widgetStyle == "compact"
        let saveKey = currentFrameKey
        let savedFrame = UserDefaults.standard.string(forKey: saveKey).map(NSRectFromString)
        let initialRect = FloatingWidgetLayout.initialFrame(isCompact: isCompact, savedFrame: savedFrame)

        let newPanel = NSPanel(
            contentRect: clamped(initialRect, bounds: FloatingWidgetLayout.bounds(forCompact: isCompact, template: model.interfaceTemplate)),
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
        let newPanelBounds = FloatingWidgetLayout.bounds(forCompact: isCompact, template: model.interfaceTemplate)
        newPanel.minSize = newPanelBounds.minSize
        newPanel.maxSize = newPanelBounds.maxSize

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
