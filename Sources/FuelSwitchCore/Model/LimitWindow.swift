import Foundation

public struct LimitWindow: Equatable, Sendable, Codable {
    public let percent: Double
    public let resetsAt: Date?
    public let label: String

    public init(percent: Double, resetsAt: Date?, label: String) {
        self.percent = percent
        self.resetsAt = resetsAt
        self.label = label
    }

    public static let empty = LimitWindow(percent: 0, resetsAt: nil, label: "—")

    /// Remaining fuel percentage (100% minus percent used).
    public var remainingPercent: Double {
        max(0, 100.0 - percent)
    }

    /// Whether this window is running on reserve fuel (< 20% remaining).
    public var isLowFuel: Bool {
        remainingPercent < 20.0
    }
}

public enum Staleness: Equatable, Sendable {
    case fresh
    case cached(since: Date)
    case error(String)
}

public struct AccountUsage: Equatable, Sendable {
    public let session: LimitWindow
    public let weekly: LimitWindow
    public let scoped: [LimitWindow]
    public let fetchedAt: Date
    public let staleness: Staleness
    public let resetCreditsAvailable: Int?
    public let resetCreditId: String?

    public init(
        session: LimitWindow,
        weekly: LimitWindow,
        scoped: [LimitWindow],
        fetchedAt: Date,
        staleness: Staleness,
        resetCreditsAvailable: Int? = nil,
        resetCreditId: String? = nil
    ) {
        self.session = session
        self.weekly = weekly
        self.scoped = scoped
        self.fetchedAt = fetchedAt
        self.staleness = staleness
        self.resetCreditsAvailable = resetCreditsAvailable
        self.resetCreditId = resetCreditId
    }

    /// The highest usage across every window — this is what the menu bar icon
    /// shows.
    public var worstPercent: Double {
        ([session.percent, weekly.percent] + scoped.map(\.percent)).max() ?? 0
    }

    /// Remaining fuel percentage (100% minus worst usage).
    public var remainingPercent: Double {
        max(0, 100.0 - worstPercent)
    }

    /// Whether this account is running on reserve fuel (< 20% remaining).
    public var isLowFuel: Bool {
        remainingPercent < 20.0
    }
}
