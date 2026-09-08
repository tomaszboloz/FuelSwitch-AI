import Foundation

public enum PaceTier: String, Sendable, Equatable {
    case ahead
    case onPace
    case burningFast
}

public struct PaceEstimate: Equatable, Sendable {
    public let tier: PaceTier
    public let usedPercent: Double
    public let elapsedFraction: Double

    public init(tier: PaceTier, usedPercent: Double, elapsedFraction: Double) {
        self.tier = tier
        self.usedPercent = usedPercent
        self.elapsedFraction = elapsedFraction
    }
}

public enum PaceEstimator {
    public static let sessionWindowDuration: TimeInterval = 5 * 3600
    public static let weeklyWindowDuration: TimeInterval = 7 * 24 * 3600

    private static let burningFastMargin: Double = 15
    private static let aheadMargin: Double = -15

    /// Compares used% against elapsed% of the window. `windowDuration` is an
    /// assumed constant (5h session / 7d weekly) rather than something the API
    /// reports — brittle if a provider ever ships a plan tier with a different
    /// window length.
    public static func estimate(window: LimitWindow, windowDuration: TimeInterval, now: Date = Date()) -> PaceEstimate? {
        guard windowDuration > 0 else { return nil }
        guard let resetsAt = window.resetsAt, resetsAt > now else { return nil }
        guard window.percent > 0 else { return nil }

        let remaining = resetsAt.timeIntervalSince(now)
        let elapsed = windowDuration - remaining
        guard elapsed > 0 else { return nil }

        let elapsedFraction = min(1, elapsed / windowDuration)
        let delta = window.percent - (elapsedFraction * 100)

        let tier: PaceTier
        if delta > burningFastMargin {
            tier = .burningFast
        } else if delta < aheadMargin {
            tier = .ahead
        } else {
            tier = .onPace
        }

        return PaceEstimate(tier: tier, usedPercent: window.percent, elapsedFraction: elapsedFraction)
    }
}
