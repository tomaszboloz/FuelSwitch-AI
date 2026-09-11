import Foundation

/// Pure frame-sizing rules for the floating HUD panel. Kept out of the
/// `FloatingWidgetController` (AppKit) so the actual arithmetic — which is
/// the part that regresses silently — is unit-testable without an `NSPanel`.
public enum FloatingWidgetLayout {
    public struct Bounds: Sendable, Equatable {
        public let minSize: CGSize
        public let maxSize: CGSize
    }

    public static let compactBounds = Bounds(
        minSize: CGSize(width: 580, height: 42),
        maxSize: CGSize(width: 900, height: 70)
    )

    public static let expandedBounds = Bounds(
        minSize: CGSize(width: 260, height: 160),
        maxSize: CGSize(width: 900, height: 900)
    )

    public static func bounds(forCompact isCompact: Bool, template: InterfaceTemplate = .classic) -> Bounds {
        if template == .native {
            return isCompact
                ? Bounds(minSize: CGSize(width: 860, height: 70), maxSize: CGSize(width: 1400, height: 70))
                : Bounds(minSize: CGSize(width: 380, height: 300), maxSize: CGSize(width: 900, height: 900))
        }
        return isCompact ? compactBounds : expandedBounds
    }

    /// Whether a previously-saved frame is still a legal size for the given
    /// style — a stale save from before `compactBounds`/`expandedBounds`
    /// changed should fall back to the default rather than clamp silently.
    public static func isValidSavedFrame(_ rect: CGRect, isCompact: Bool) -> Bool {
        let bounds = bounds(forCompact: isCompact)
        guard rect.width >= bounds.minSize.width, rect.height >= bounds.minSize.height else { return false }
        if isCompact {
            return rect.height <= bounds.maxSize.height
        }
        return true
    }

    /// Frame to switch `currentFrame`'s panel to when toggling compact/expanded,
    /// anchored at the current frame's top-left so the panel doesn't jump.
    public static func targetFrame(currentFrame: CGRect, switchingToCompact isCompact: Bool, savedFrame: CGRect?) -> CGRect {
        let defaultHeight: CGFloat = isCompact ? 46 : 320
        let defaultWidth: CGFloat = isCompact ? max(currentFrame.width, 660) : max(currentFrame.width, 340)
        if let savedFrame, isValidSavedFrame(savedFrame, isCompact: isCompact) {
            return CGRect(x: currentFrame.minX, y: currentFrame.maxY - savedFrame.height, width: savedFrame.width, height: savedFrame.height)
        }
        return CGRect(x: currentFrame.minX, y: currentFrame.maxY - defaultHeight, width: defaultWidth, height: defaultHeight)
    }

    /// Frame for a brand-new panel (first show, or after being fully hidden).
    public static func initialFrame(isCompact: Bool, savedFrame: CGRect?) -> CGRect {
        if let savedFrame, isValidSavedFrame(savedFrame, isCompact: isCompact) {
            return savedFrame
        }
        return isCompact
            ? CGRect(x: 120, y: 150, width: 660, height: 46)
            : CGRect(x: 120, y: 150, width: 340, height: 340)
    }
}
