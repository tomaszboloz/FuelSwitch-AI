import SwiftUI
import AppKit
import FuelSwitchCore

/// The menu bar indicator: one rounded rectangle per provider, filled from the
/// bottom up to that provider's best account. The empty space on top is
/// the fuel capacity that is left.
///
/// The whole label is drawn as a single `NSImage`, text included, rather than
/// composed from SwiftUI views. A `MenuBarExtra` label renders only the first
/// element of a `ForEach` — measured: 31 pt for what should have been two
/// glyphs — so anything dynamic has to be one image by the time SwiftUI sees
/// it. Being a template image also gets it the correct colour in a light bar,
/// a dark bar and the highlighted state.
enum MenuBarIcon {
    /// Sized to match the system icons in the menu bar.
    private static let glyph = NSSize(width: 13, height: 16)
    private static let glyphToText: CGFloat = 4
    private static let betweenReadings: CGFloat = 11

    private static var textFont: NSFont {
        .monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
    }

    private static var providerFont: NSFont {
        .systemFont(ofSize: 8, weight: .bold)
    }

    private static var badgeFont: NSFont {
        .systemFont(ofSize: 8, weight: .heavy)
    }

    /// `AppModel` lives on the main actor, so reading its state has to be
    /// isolated to it — otherwise strict concurrency rejects the build.
    @MainActor
    static func label(for model: AppModel) -> some View {
        MenuBarLabelView(model: model)
    }

    struct MenuBarLabelView: View {
        // Must be @ObservedObject, not a plain `var` — without it SwiftUI
        // never subscribes to `model`'s @Published changes, so the label
        // paints once at launch and freezes. Claude looked fine anyway
        // because its usage is bootstrapped synchronously from
        // ~/.claude.json before that first paint; Codex and Gemini have no
        // such bootstrap, so they froze empty even as `usage` kept updating
        // correctly underneath.
        @ObservedObject var model: AppModel

        var body: some View {
            Image(nsImage: MenuBarIcon.image(
                readings: model.menuBarReadings,
                showsPercent: model.showsPercentInMenuBar,
                iconStyle: model.menuBarIconStyle
            ))
        }
    }

    static func image(readings: [MenuBarReading], showsPercent: Bool, iconStyle: MenuBarIconStyle = .gauge) -> NSImage {
        // percentOnly has no glyph to speak of, so the text is the entire
        // point of the style — it always shows regardless of the separate
        // showsPercent toggle.
        let effectiveShowsPercent = iconStyle == .percentOnly ? true : showsPercent
        let showsGlyph = iconStyle != .percentOnly

        // No accounts at all still needs a glyph to click on.
        let parts: [(provider: Provider?, fill: Double?, text: String?)] = readings.isEmpty
            ? [(nil, nil, nil)]
            : readings.map { (provider: $0.provider, fill: $0.fill, text: effectiveShowsPercent ? $0.text : nil) }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor,
        ]

        let providerAttributes: [NSAttributedString.Key: Any] = [
            .font: providerFont,
            .foregroundColor: NSColor.labelColor,
        ]

        let totalHeight: CGFloat = effectiveShowsPercent ? 20 : glyph.height

        var width: CGFloat = 0
        for (index, part) in parts.enumerated() {
            if index > 0 { width += betweenReadings }

            if !effectiveShowsPercent, let provider = part.provider {
                let badgeStr = provider.monogram as NSString
                let badgeTextSize = badgeStr.size(withAttributes: [.font: badgeFont])
                width += (badgeTextSize.width + 5) + 3
            }

            if showsGlyph { width += glyph.width }

            if let text = part.text {
                let textSize = (text as NSString).size(withAttributes: textAttributes)
                let providerTitle = (part.provider?.menuBarLabel ?? "") as NSString
                let providerTitleSize = providerTitle.size(withAttributes: providerAttributes)
                let textBlockWidth = max(textSize.width, providerTitleSize.width)
                width += glyphToText + textBlockWidth
            }
        }

        let image = NSImage(size: NSSize(width: width, height: totalHeight), flipped: false) { _ in
            var x: CGFloat = 0
            for (index, part) in parts.enumerated() {
                if index > 0 { x += betweenReadings }

                let gaugeY = (totalHeight - glyph.height) / 2

                if !effectiveShowsPercent, let provider = part.provider {
                    let badgeStr = provider.monogram as NSString
                    let badgeTextSize = badgeStr.size(withAttributes: [.font: badgeFont])
                    let badgeW = badgeTextSize.width + 5
                    let badgeH: CGFloat = 13
                    let badgeRect = NSRect(x: x, y: (totalHeight - badgeH) / 2, width: badgeW, height: badgeH)
                    let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
                    NSColor.labelColor.setFill()
                    badgePath.fill()
                    badgeStr.draw(
                        at: NSPoint(x: badgeRect.midX - badgeTextSize.width / 2, y: badgeRect.midY - badgeTextSize.height / 2 + 0.4),
                        withAttributes: [.font: badgeFont, .foregroundColor: NSColor.textBackgroundColor]
                    )
                    x += badgeW + 3
                }

                if showsGlyph {
                    let glyphRect = NSRect(x: x, y: gaugeY, width: glyph.width, height: glyph.height)
                    switch iconStyle {
                    case .percentOnly:
                        break // unreachable: showsGlyph is false whenever iconStyle is .percentOnly
                    case .gauge:
                        drawGauge(fill: part.fill, in: glyphRect, monochrome: false)
                    case .monochrome:
                        drawGauge(fill: part.fill, in: glyphRect, monochrome: true)
                    case .battery:
                        drawBattery(fill: part.fill, in: glyphRect)
                    }
                    x += glyph.width
                }

                if let text = part.text {
                    x += glyphToText
                    let providerTitle = (part.provider?.menuBarLabel ?? "") as NSString
                    providerTitle.draw(
                        at: NSPoint(x: x, y: gaugeY + 9.5),
                        withAttributes: providerAttributes
                    )

                    let size = (text as NSString).size(withAttributes: textAttributes)
                    (text as NSString).draw(
                        at: NSPoint(x: x, y: gaugeY - 1.0),
                        withAttributes: textAttributes
                    )

                    let providerTitleSize = providerTitle.size(withAttributes: providerAttributes)
                    x += max(size.width, providerTitleSize.width)
                }
            }
            return true
        }
        // Keep the fuel mark orange when an active quota reaches reserve. A
        // template image would force monochrome system tinting and hide that
        // warning precisely where the compact menu-bar indicator matters.
        image.isTemplate = false
        return image
    }

    /// `fill` ranges over 0...100; `nil` draws the outline alone, so missing
    /// data does not look like a completely empty account. `monochrome`
    /// suppresses the low-fuel orange tint for anyone who finds it distracting.
    private static func drawGauge(fill: Double?, in rect: NSRect, monochrome: Bool) {
        let body = rect.insetBy(dx: 1, dy: 1.5)
        let radius: CGFloat = 3.5

        let outline = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
        outline.lineWidth = 1.3
        let isReserve = !monochrome && (fill ?? 100) < 20
        let fuelColor = isReserve ? NSColor.systemOrange : NSColor.labelColor
        fuelColor.setStroke()
        outline.stroke()

        guard let fill, fill > 0 else { return }

        // The fill sits inside the outline, so the stroke stays legible even at
        // 100%.
        let inner = body.insetBy(dx: 1.6, dy: 1.6)
        let ratio = min(max(fill / 100, 0), 1)
        let height = inner.height * ratio
        guard height > 0.4 else { return }

        // Clipped to the inner shape so that at full level the corners are
        // rounded exactly like the outline.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: radius - 1.6, yRadius: radius - 1.6).setClip()
        fuelColor.setFill()
        NSBezierPath(rect: NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: height)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A horizontal battery shape with a small nub, filled left to right.
    /// `fill` ranges over 0...100; `nil` draws the outline alone.
    private static func drawBattery(fill: Double?, in rect: NSRect) {
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
