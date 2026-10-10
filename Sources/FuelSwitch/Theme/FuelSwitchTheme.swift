import SwiftUI

/// Unified Design System tokens for FuelSwitch AI.
public enum FuelSwitchTheme {
    // MARK: - Color Palette (Adaptive for Dark & Light with WCAG AA Contrast)

    @MainActor
    public static var isDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    public static let bgDeep = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.043, green: 0.059, blue: 0.090, alpha: 1.0)
            : NSColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
    }))

    public static let bgPanel = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.067, green: 0.094, blue: 0.141, alpha: 1.0)
            : NSColor(red: 0.98, green: 0.985, blue: 0.99, alpha: 1.0)
    }))

    public static let bgCard = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.094, green: 0.125, blue: 0.180, alpha: 1.0)
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

    public static let borderActive = FuelSwitchTheme.amber.opacity(0.45)

    // Accents
    public static let cyanAccent = Color(red: 0.06, green: 0.72, blue: 0.85)
    public static let emerald = Color(red: 0.10, green: 0.75, blue: 0.50)
    public static let amber = Color(red: 0.96, green: 0.62, blue: 0.07)
    public static let crimson = Color(red: 0.94, green: 0.27, blue: 0.27)

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
        return amber
    }
}
