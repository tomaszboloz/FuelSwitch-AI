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

        let bounds = FloatingWidgetLayout.bounds(forCompact: isCompact)
        panel.minSize = bounds.minSize
        panel.maxSize = bounds.maxSize

        // Save the frame of the style we're leaving, so switching back restores it.
        let otherStyleKey = isCompact ? expandedFrameKey : compactFrameKey
        UserDefaults.standard.set(NSStringFromRect(current), forKey: otherStyleKey)

        let savedFrame = UserDefaults.standard.string(forKey: currentFrameKey).map(NSRectFromString)
        let targetRect = FloatingWidgetLayout.targetFrame(currentFrame: current, switchingToCompact: isCompact, savedFrame: savedFrame)
        panel.setFrame(targetRect, display: true, animate: true)
    }

    private func showWidget() {
        guard let model else { return }

        if let existing = panel {
            existing.orderFront(nil)
            return
        }

        let isCompact = model.widgetStyle == "compact"
        let saveKey = isCompact ? compactFrameKey : expandedFrameKey
        let savedFrame = UserDefaults.standard.string(forKey: saveKey).map(NSRectFromString)
        let initialRect = FloatingWidgetLayout.initialFrame(isCompact: isCompact, savedFrame: savedFrame)

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
        let newPanelBounds = FloatingWidgetLayout.bounds(forCompact: isCompact)
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
