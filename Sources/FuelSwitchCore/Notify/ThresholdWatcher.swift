import Foundation

/// A threshold newly crossed by an account's usage, ready to become a
/// notification. Carries the raw numbers rather than formatted text — the
/// app layer decides how to phrase it, and in which language.
public struct ThresholdCrossing: Equatable, Sendable {
    public let windowLabel: String
    public let threshold: Int
    public let remainingPercent: Double

    public init(windowLabel: String, threshold: Int, remainingPercent: Double) {
        self.windowLabel = windowLabel
        self.threshold = threshold
        self.remainingPercent = remainingPercent
    }
}

/// Tracks which usage thresholds have already fired a notification, per
/// account and window, so the same crossing does not notify twice.
///
/// State is keyed on `"\(accountId)|\(windowLabel)"` because `session` and
/// `weekly` reset on independent schedules — crossing 90% on the session
/// window says nothing about the weekly window, and each needs its own
/// re-arm.
///
/// Re-arming: once the highest configured threshold has fired, this account
/// stays quiet until `percent` drops back below the LOWEST configured
/// threshold (which happens when the window resets). Without that floor, a
/// value oscillating around one threshold (e.g. 74/76/74/76) would either
/// spam on every poll or never fire again — re-arming only after a real
/// reset avoids both.
public actor ThresholdWatcher {
    private var armedFloor: [String: Int] = [:]

    public init() {}

    private static func key(accountId: String, windowLabel: String) -> String {
        "\(accountId)|\(windowLabel)"
    }

    /// Reports the highest newly-crossed threshold, if any, for one
    /// account/window pair. `thresholds` need not be sorted or unique —
    /// this normalizes both. Returns `nil` when nothing new was crossed
    /// (including when the window is still armed above the last threshold
    /// it already reported).
    public func evaluate(
        accountId: String,
        windowLabel: String,
        percent: Double,
        thresholds: [Int]
    ) -> ThresholdCrossing? {
        let sorted = Set(thresholds).sorted()
        guard let lowest = sorted.first else { return nil }
        let key = Self.key(accountId: accountId, windowLabel: windowLabel)

        // Below the lowest configured threshold re-arms this window —
        // whatever fired before is forgotten, ready to fire again next
        // cycle.
        guard percent >= Double(lowest) else {
            armedFloor[key] = nil
            return nil
        }

        let alreadyFired = armedFloor[key] ?? 0
        // The highest step at or below the current percent — a single jump
        // from 60% to 97% reports only the highest one crossed, not every
        // step in between.
        guard let crossed = sorted.last(where: { percent >= Double($0) }), crossed > alreadyFired else {
            return nil
        }

        armedFloor[key] = crossed
        return ThresholdCrossing(
            windowLabel: windowLabel,
            threshold: crossed,
            remainingPercent: max(0, 100 - percent)
        )
    }

    /// Clears one account's armed state entirely — called on removal or
    /// re-sign-in, mirroring `Poller.forgetState`. A fresh sign-in should
    /// not inherit "already notified" from a previous session tied to the
    /// same account id.
    public func forget(accountId: String) {
        armedFloor = armedFloor.filter { !$0.key.hasPrefix("\(accountId)|") }
    }
}
