import Foundation

/// What the one number in the menu bar is supposed to answer.
///
/// These are three genuinely different questions, not three ways of phrasing
/// one. Which is right depends on how you work, so it is a setting rather than
/// a decision made for everyone.
///
/// Two candidates were deliberately left out. An AVERAGE across accounts
/// describes no account you could actually use — you work on one at a time, and
/// the mean of a full account and an empty one is a number matching neither.
/// TOTAL remaining capacity has the same defect and adds another: accounts sit
/// on different plans, so their percentages are not the same unit and summing
/// them is arithmetic on incomparable things.
public enum MenuBarMetric: String, Codable, Sendable, CaseIterable, Identifiable {
    /// "What is the status of the currently active account?" — 5h % and week %.
    case activeAccount
    /// "Is there somewhere fresh to work?" — the account you would switch to.
    case bestAccount
    /// "Is anything about to run out?" — the account closest to its limit.
    case worstAccount
    /// "How much runway is left across the fleet?" — how many accounts still
    /// have room.
    case accountsWithRoom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .activeAccount: "Active account"
        case .bestAccount: "Best account"
        case .worstAccount: "Busiest account"
        case .accountsWithRoom: "Accounts with room"
        }
    }

    public var explanation: String {
        switch self {
        case .activeAccount:
            "Remaining capacity of the active CLI account. The icon empties as quota is consumed."
        case .bestAccount:
            "Usage of the emptiest account. The icon empties as quota is used up."
        case .worstAccount:
            "Usage of the fullest account. The icon empties as it approaches the limit."
        case .accountsWithRoom:
            "How many accounts are still under \(Int(MenuBarReading.roomThreshold))%. The icon empties as accounts run out."
        }
    }
}

/// What the menu bar shows for one provider.
public struct MenuBarReading: Equatable, Sendable, Identifiable {
    public let provider: Provider
    /// How full to draw the glyph, 0...100. `nil` when nothing is known, which
    /// draws the outline alone.
    public let fill: Double?
    /// What to print beside the glyph, when the user asked for a number.
    public let text: String?

    public var id: String { provider.rawValue }

    public init(provider: Provider, fill: Double?, text: String?) {
        self.provider = provider
        self.fill = fill
        self.text = text
    }

    /// The line between an account with room and one without. It matches the
    /// point at which a limit row turns amber, so the menu bar and the panel
    /// agree about what "getting tight" means.
    public static let roomThreshold: Double = 80

    /// One reading per provider that has accounts, and deliberately not one
    /// number for everything: running out of Claude Code is not helped by Codex
    /// sitting idle.
    ///
    /// Whatever the metric, an account is measured by its WORST window — an
    /// account is only as usable as its tightest limit.
    ///
    /// Accounts in an error state with no cache at all are excluded rather than
    /// counted as 0%: counting them would make the menu bar look better than it
    /// is precisely when least is known.
    public static func all(
        accounts: [Account],
        usage: [String: AccountUsage],
        metric: MenuBarMetric,
        activeEmails: [Provider: String] = [:]
    ) -> [MenuBarReading] {
        Provider.allCases.compactMap { provider in
            let providerAccounts = accounts.filter { $0.provider == provider }
            guard !providerAccounts.isEmpty else { return nil }

            let ids = providerAccounts.map(\.id)

            let known = ids.compactMap { id -> Double? in
                guard let accountUsage = usage[id] else { return nil }
                if case .error = accountUsage.staleness { return nil }
                return accountUsage.worstPercent
            }

            switch metric {
            case .activeAccount:
                let activeAccount: Account? = {
                    if let activeEmail = activeEmails[provider],
                       let matching = providerAccounts.first(where: { $0.email.lowercased() == activeEmail.lowercased() }) {
                        return matching
                    }
                    // If no explicit active account or active not found, pick the first account that has non-error usage
                    return providerAccounts.first { account in
                        guard let accountUsage = usage[account.id] else { return false }
                        if case .error = accountUsage.staleness { return false }
                        return true
                    } ?? providerAccounts.first
                }()

                guard let activeAccount, let accountUsage = usage[activeAccount.id] else {
                    return MenuBarReading(provider: provider, fill: nil, text: nil)
                }

                if case .error = accountUsage.staleness {
                    return MenuBarReading(provider: provider, fill: nil, text: nil)
                }

                let sessionRemaining = Int(accountUsage.session.remainingPercent)
                let weeklyRemaining = Int(accountUsage.weekly.remainingPercent)
                // The glyph empties as quota is consumed (full = 100% fuel remaining)
                let fill = max(0, 100.0 - accountUsage.worstPercent)

                return MenuBarReading(
                    provider: provider,
                    fill: fill,
                    text: "\(sessionRemaining)% / \(weeklyRemaining)%"
                )

            case .bestAccount:
                return reading(provider: provider, percent: known.min())
            case .worstAccount:
                return reading(provider: provider, percent: known.max())
            case .accountsWithRoom:
                guard !known.isEmpty else {
                    return MenuBarReading(provider: provider, fill: nil, text: nil)
                }
                let withRoom = known.filter { $0 < roomThreshold }.count
                // The glyph empties as accounts run out of room
                let remainingFraction = Double(withRoom) / Double(known.count) * 100
                return MenuBarReading(provider: provider, fill: remainingFraction, text: "\(withRoom)")
            }
        }
    }

    private static func reading(provider: Provider, percent: Double?) -> MenuBarReading {
        MenuBarReading(
            provider: provider,
            fill: percent.map { max(0, 100.0 - $0) },
            text: percent.map { "\(Int(max(0, 100.0 - $0)))%" }
        )
    }
}
