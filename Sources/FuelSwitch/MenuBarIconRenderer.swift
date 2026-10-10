import AppKit
import FuelSwitchCore

enum MenuBarIconRenderer {
    /// `fill` ranges over 0...100; `nil` draws the outline alone.
    static func drawGauge(fill: Double?, in rect: NSRect, monochrome: Bool) {
        let body = rect.insetBy(dx: 1, dy: 1.5)
        let radius: CGFloat = 3.5

        let outline = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
        outline.lineWidth = 1.3
        let isReserve = !monochrome && (fill ?? 100) < 20
        let fuelColor = isReserve ? NSColor.systemOrange : NSColor.labelColor
        fuelColor.setStroke()
        outline.stroke()

        guard let fill, fill > 0 else { return }

        let inner = body.insetBy(dx: 1.6, dy: 1.6)
        let ratio = min(max(fill / 100, 0), 1)
        let height = inner.height * ratio
        guard height > 0.4 else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: radius - 1.6, yRadius: radius - 1.6).setClip()
        fuelColor.setFill()
        NSBezierPath(rect: NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: height)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A horizontal battery shape with a small nub, filled left to right.
    static func drawBattery(fill: Double?, in rect: NSRect) {
        let nubWidth: CGFloat = 1.6
        let bodyRect = NSRect(
            x: rect.minX,
            y: rect.minY + rect.height * 0.28,
            width: rect.width - nubWidth - 1,
            height: rect.height * 0.44
        )
        let radius: CGFloat = 1.5

        let outline = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
        outline.lineWidth = 1.2
        let isReserve = (fill ?? 100) < 20
        let fuelColor = isReserve ? NSColor.systemOrange : NSColor.labelColor
        fuelColor.setStroke()
        outline.stroke()

        let nubRect = NSRect(x: bodyRect.maxX + 1, y: bodyRect.midY - 2, width: nubWidth, height: 4)
        fuelColor.setFill()
        NSBezierPath(roundedRect: nubRect, xRadius: 0.6, yRadius: 0.6).fill()

        guard let fill, fill > 0 else { return }

        let inner = bodyRect.insetBy(dx: 1.4, dy: 1.4)
        let ratio = min(max(fill / 100, 0), 1)
        let width = inner.width * ratio
        guard width > 0.4 else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: max(0, radius - 1.4), yRadius: max(0, radius - 1.4)).setClip()
        fuelColor.setFill()
        NSBezierPath(rect: NSRect(x: inner.minX, y: inner.minY, width: width, height: inner.height)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
