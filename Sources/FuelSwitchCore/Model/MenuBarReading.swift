import Foundation

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
                return activeAccountReading(
                    provider: provider,
                    providerAccounts: providerAccounts,
                    usage: usage,
                    activeEmail: activeEmails[provider]
                )
            case .bestAccount:
                return reading(provider: provider, percent: known.min())
            case .worstAccount:
                return reading(provider: provider, percent: known.max())
            case .accountsWithRoom:
                return accountsWithRoomReading(provider: provider, known: known)
            }
        }
    }

    private static func activeAccountReading(
        provider: Provider,
        providerAccounts: [Account],
        usage: [String: AccountUsage],
        activeEmail: String?
    ) -> MenuBarReading {
        let activeAccount = findActiveAccount(providerAccounts: providerAccounts, usage: usage, activeEmail: activeEmail)
        guard let activeAccount, let accountUsage = usage[activeAccount.id] else {
            return MenuBarReading(provider: provider, fill: nil, text: nil)
        }
        if case .error = accountUsage.staleness {
            return MenuBarReading(provider: provider, fill: nil, text: nil)
        }
        let sessionRemaining = Int(accountUsage.session.remainingPercent)
        let weeklyRemaining = Int(accountUsage.weekly.remainingPercent)
        let fill = max(0, 100.0 - accountUsage.worstPercent)
        return MenuBarReading(
            provider: provider,
            fill: fill,
            text: "\(sessionRemaining)% / \(weeklyRemaining)%"
        )
    }

    private static func findActiveAccount(
        providerAccounts: [Account],
        usage: [String: AccountUsage],
        activeEmail: String?
    ) -> Account? {
        if let activeEmail,
           let matching = providerAccounts.first(where: { $0.email.lowercased() == activeEmail.lowercased() }) {
            return matching
        }
        return providerAccounts.first { account in
            guard let accountUsage = usage[account.id] else { return false }
            if case .error = accountUsage.staleness { return false }
            return true
        } ?? providerAccounts.first
    }

    private static func accountsWithRoomReading(provider: Provider, known: [Double]) -> MenuBarReading {
        guard !known.isEmpty else {
            return MenuBarReading(provider: provider, fill: nil, text: nil)
        }
        let withRoom = known.filter { $0 < roomThreshold }.count
        let remainingFraction = Double(withRoom) / Double(known.count) * 100
        return MenuBarReading(provider: provider, fill: remainingFraction, text: "\(withRoom)")
    }

    private static func reading(provider: Provider, percent: Double?) -> MenuBarReading {
        MenuBarReading(
            provider: provider,
            fill: percent.map { max(0, 100.0 - $0) },
            text: percent.map { "\(Int(max(0, 100.0 - $0)))%" }
        )
    }
}
