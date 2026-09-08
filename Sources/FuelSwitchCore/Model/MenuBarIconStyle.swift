import Foundation

/// How the menu bar glyph is drawn. Independent of `MenuBarMetric` (what
/// number it shows) — this is purely how it looks.
public enum MenuBarIconStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The original vertical fuel-gauge rectangle. Default.
    case gauge
    /// A horizontal battery shape with a nub, filled left to right.
    case battery
    /// No glyph at all — just the percentage text.
    case percentOnly
    /// The gauge glyph, but never tinted orange at low fuel — for anyone who
    /// finds the color change distracting rather than useful.
    case monochrome

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .gauge: "Gauge"
        case .battery: "Battery"
        case .percentOnly: "Percent only"
        case .monochrome: "Monochrome"
        }
    }
}
