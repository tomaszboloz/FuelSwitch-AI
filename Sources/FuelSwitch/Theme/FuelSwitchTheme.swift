import SwiftUI

/// Unified Design System tokens and custom components for FuelSwitch AI.
/// Shared across both the Menu Bar panel and the Floating Desktop Widget.
public enum FuelSwitchTheme {
    // MARK: - Color Palette (Adaptive for Dark & Light with WCAG AA Contrast)

    @MainActor
    public static var isDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    public static let bgDeep = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.043, green: 0.059, blue: 0.090, alpha: 1.0) // #0B0F17
            : NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    }))

    public static let bgPanel = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.067, green: 0.094, blue: 0.141, alpha: 1.0) // #111824
            : NSColor(red: 0.98, green: 0.985, blue: 0.99, alpha: 1.0)
    }))

    public static let bgCard = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.094, green: 0.125, blue: 0.180, alpha: 1.0) // #18202E
            : NSColor(white: 1.0, alpha: 1.0)
    }))

    public static let bgCardHover = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.125, green: 0.165, blue: 0.231, alpha: 1.0)
            : NSColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0)
    }))

    public static let bgCardSubtle = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.078, green: 0.106, blue: 0.153, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1.0)
    }))
    
    public static let borderSubtle = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(white: 0.0, alpha: 0.08)
    }))

    public static let borderRegular = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.14)
            : NSColor(white: 0.0, alpha: 0.15)
    }))

    public static let borderActive = FuelSwitchTheme.amber.opacity(0.45) // Amber glow

    // Accents
    public static let cyanAccent = Color(red: 0.06, green: 0.72, blue: 0.85) // Electric Cyan #0EB5D9
    public static let emerald = Color(red: 0.10, green: 0.75, blue: 0.50) // Emerald Mint #10B981
    public static let amber = Color(red: 0.96, green: 0.62, blue: 0.07) // Fuel Amber #F59E0B
    public static let crimson = Color(red: 0.94, green: 0.27, blue: 0.27) // Warning Red #EF4444

    public static let textPrimary = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
            : NSColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1.0)
    }))

    public static let textSecondary = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 1.0)
            : NSColor(red: 0.35, green: 0.42, blue: 0.52, alpha: 1.0)
    }))

    public static let textTertiary = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.38, green: 0.44, blue: 0.53, alpha: 1.0)
            : NSColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1.0)
    }))

    public static func fuelColor(percentUsed: Double, isResetPassed: Bool = false) -> Color {
        if isResetPassed { return textSecondary }
        if percentUsed >= 100 { return crimson }
        if percentUsed >= 80 { return amber }
        return amber  // Primary color is now amber
    }
}

// MARK: - FuelGauge Component
/// Precision fuel bar with segmented glowing track and tabular typography.
public struct FuelGauge: View {
    public let value: Double // 0...100%
    public let color: Color
    public var height: CGFloat = 6
    public var showSegments: Bool = true

    public init(value: Double, color: Color, height: CGFloat = 6, showSegments: Bool = true) {
        self.value = max(0, min(100, value))
        self.color = color
        self.height = height
        self.showSegments = showSegments
    }

    public var body: some View {
        GeometryReader { geo in
            let fillWidth = max(0, min(geo.size.width, geo.size.width * CGFloat(value / 100.0)))

            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.06))

                // Fuel Fill with subtle glow
                if fillWidth > 0 {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.85), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)
                }

                // Precision Notch Markers at 25%, 50%, 75%
                if showSegments && geo.size.width > 120 {
                    HStack(spacing: 0) {
                        Spacer()
                        tick
                        Spacer()
                        tick
                        Spacer()
                        tick
                        Spacer()
                    }
                }
            }
        }
        .frame(height: height)
    }

    private var tick: some View {
        Rectangle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 1, height: height)
    }
}

// MARK: - FuelBadge Component
public struct FuelBadge: View {
    public enum BadgeType {
        case active
        case standby
        case exhausted
        case reauth
    }

    public let type: BadgeType
    public let title: String

    public init(type: BadgeType, title: String) {
        self.type = type
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 5, height: 5)
                .shadow(color: indicatorColor.opacity(0.6), radius: 2)

            Text(title)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(indicatorColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(indicatorColor.opacity(0.3), lineWidth: 0.8)
        )
        .foregroundStyle(indicatorColor)
    }

    private var indicatorColor: Color {
        switch type {
        case .active: return FuelSwitchTheme.emerald
        case .standby: return FuelSwitchTheme.cyanAccent
        case .exhausted: return FuelSwitchTheme.crimson
        case .reauth: return FuelSwitchTheme.amber
        }
    }

}

// MARK: - LowFuelIndicator Component
/// Amber warning indicator with gas tank icon signaling < 20% remaining fuel.
public struct LowFuelIndicator: View {
    public var size: CGFloat = 11
    public var showText: Bool = false
    public var text: String? = nil

    public init(size: CGFloat = 11, showText: Bool = false, text: String? = nil) {
        self.size = size
        self.showText = showText
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 3.5) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(FuelSwitchTheme.amber)
                .shadow(color: FuelSwitchTheme.amber.opacity(0.5), radius: 2)

            if showText, let text {
                Text(text)
                    .font(.system(size: 8.5, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.amber)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(FuelSwitchTheme.amber.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(FuelSwitchTheme.amber.opacity(0.40), lineWidth: 0.8)
        )
    }
}
