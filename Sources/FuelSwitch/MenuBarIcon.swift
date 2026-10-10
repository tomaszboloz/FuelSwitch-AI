import SwiftUI
import AppKit
import FuelSwitchCore

/// Menu bar indicator image generation and view wrapper.
enum MenuBarIcon {
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

    @MainActor
    static func label(for model: AppModel) -> some View {
        MenuBarLabelView(model: model)
    }

    struct MenuBarLabelView: View {
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
        let effectiveShowsPercent = iconStyle == .percentOnly ? true : showsPercent
        let showsGlyph = iconStyle != .percentOnly

        let parts: [(provider: Provider?, fill: Double?, text: String?)] = readings.isEmpty
            ? [(nil, nil, nil)]
            : readings.map { (provider: $0.provider, fill: $0.fill, text: effectiveShowsPercent ? $0.text : nil) }

        let textAttributes: [NSAttributedString.Key: Any] = [.font: textFont, .foregroundColor: NSColor.labelColor]
        let providerAttributes: [NSAttributedString.Key: Any] = [.font: providerFont, .foregroundColor: NSColor.labelColor]
        let totalHeight: CGFloat = effectiveShowsPercent ? 20 : glyph.height

        let width = calculateWidth(parts: parts, effectiveShowsPercent: effectiveShowsPercent, showsGlyph: showsGlyph, textAttributes: textAttributes, providerAttributes: providerAttributes)

        let image = NSImage(size: NSSize(width: width, height: totalHeight), flipped: false) { _ in
            drawContent(parts: parts, effectiveShowsPercent: effectiveShowsPercent, showsGlyph: showsGlyph, iconStyle: iconStyle, totalHeight: totalHeight, textAttributes: textAttributes, providerAttributes: providerAttributes)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func calculateWidth(parts: [(provider: Provider?, fill: Double?, text: String?)], effectiveShowsPercent: Bool, showsGlyph: Bool, textAttributes: [NSAttributedString.Key: Any], providerAttributes: [NSAttributedString.Key: Any]) -> CGFloat {
        var width: CGFloat = 0
        for (index, part) in parts.enumerated() {
            if index > 0 { width += betweenReadings }
            if !effectiveShowsPercent, let provider = part.provider {
                let badgeStr = provider.monogram as NSString
                width += (badgeStr.size(withAttributes: [.font: badgeFont]).width + 5) + 3
            }
            if showsGlyph { width += glyph.width }
            if let text = part.text {
                let textSize = (text as NSString).size(withAttributes: textAttributes)
                let providerTitle = (part.provider?.menuBarLabel ?? "") as NSString
                let providerTitleSize = providerTitle.size(withAttributes: providerAttributes)
                width += glyphToText + max(textSize.width, providerTitleSize.width)
            }
        }
        return width
    }

    private static func drawContent(parts: [(provider: Provider?, fill: Double?, text: String?)], effectiveShowsPercent: Bool, showsGlyph: Bool, iconStyle: MenuBarIconStyle, totalHeight: CGFloat, textAttributes: [NSAttributedString.Key: Any], providerAttributes: [NSAttributedString.Key: Any]) {
        var x: CGFloat = 0
        for (index, part) in parts.enumerated() {
            if index > 0 { x += betweenReadings }
            let gaugeY = (totalHeight - glyph.height) / 2

            if !effectiveShowsPercent, let provider = part.provider {
                x = drawBadge(provider: provider, atX: x, totalHeight: totalHeight)
            }
            if showsGlyph {
                drawGlyph(style: iconStyle, fill: part.fill, atX: x, gaugeY: gaugeY)
                x += glyph.width
            }
            if let text = part.text {
                x = drawText(part: part, text: text, atX: x, gaugeY: gaugeY, textAttributes: textAttributes, providerAttributes: providerAttributes)
            }
        }
    }

    private static func drawBadge(provider: Provider, atX x: CGFloat, totalHeight: CGFloat) -> CGFloat {
        let badgeStr = provider.monogram as NSString
        let badgeTextSize = badgeStr.size(withAttributes: [.font: badgeFont])
        let badgeW = badgeTextSize.width + 5
        let badgeRect = NSRect(x: x, y: (totalHeight - 13) / 2, width: badgeW, height: 13)
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 3, yRadius: 3)
        NSColor.labelColor.setFill()
        badgePath.fill()
        badgeStr.draw(
            at: NSPoint(x: badgeRect.midX - badgeTextSize.width / 2, y: badgeRect.midY - badgeTextSize.height / 2 + 0.4),
            withAttributes: [.font: badgeFont, .foregroundColor: NSColor.textBackgroundColor]
        )
        return x + badgeW + 3
    }

    private static func drawGlyph(style: MenuBarIconStyle, fill: Double?, atX x: CGFloat, gaugeY: CGFloat) {
        let glyphRect = NSRect(x: x, y: gaugeY, width: glyph.width, height: glyph.height)
        switch style {
        case .percentOnly: break
        case .gauge: MenuBarIconRenderer.drawGauge(fill: fill, in: glyphRect, monochrome: false)
        case .monochrome: MenuBarIconRenderer.drawGauge(fill: fill, in: glyphRect, monochrome: true)
        case .battery: MenuBarIconRenderer.drawBattery(fill: fill, in: glyphRect)
        }
    }

    private static func drawText(part: (provider: Provider?, fill: Double?, text: String?), text: String, atX x: CGFloat, gaugeY: CGFloat, textAttributes: [NSAttributedString.Key: Any], providerAttributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let px = x + glyphToText
        let providerTitle = (part.provider?.menuBarLabel ?? "") as NSString
        providerTitle.draw(at: NSPoint(x: px, y: gaugeY + 9.5), withAttributes: providerAttributes)
        (text as NSString).draw(at: NSPoint(x: px, y: gaugeY - 1.0), withAttributes: textAttributes)
        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let providerTitleSize = providerTitle.size(withAttributes: providerAttributes)
        return px + max(textSize.width, providerTitleSize.width)
    }
}
