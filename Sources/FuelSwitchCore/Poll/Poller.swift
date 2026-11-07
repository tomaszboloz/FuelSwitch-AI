import Foundation

/// Refreshes limit usage for every account, honouring backoff and renewal.
public actor Poller {
    public static let baseInterval: TimeInterval = 300
    public static let minimumInterval: TimeInterval = 60
    public static let tokenRefreshThreshold: TimeInterval = 600

    let store: AccountStore
    let providers: [Provider: any UsageProvider]
    let oauth: [Provider: any OAuthProvider]
    let codexAuthURL: URL?
    let claudeConfigURL: URL
    let clock: @Sendable () async -> Date
    public internal(set) var cache: [String: AccountUsage] = [:]
    var nextDueAt: [String: Date] = [:]
    var failureCount: [String: Int] = [:]
    var lastAttempt: [String: Date] = [:]
    var credentialRefreshes: [String: Task<Account, Error>] = [:]

    public init(
        store: AccountStore,
        providers: [Provider: any UsageProvider],
        oauth: [Provider: any OAuthProvider] = [:],
        codexAuthURL: URL? = nil,
        claudeConfigURL: URL = CLISwitcher.claudeConfigURL,
        clock: @escaping @Sendable () async -> Date = { Date() }
    ) {
        self.store = store
        self.providers = providers
        self.oauth = oauth
        self.codexAuthURL = codexAuthURL
        self.claudeConfigURL = claudeConfigURL
        self.clock = clock
    }

    public func loadCache(_ new: [String: AccountUsage]) {
        cache = new
    }

    public func forgetState(id: String) {
        lastAttempt[id] = nil
        nextDueAt[id] = nil
        failureCount[id] = nil
    }

    public static func needsTokenRefresh(account: Account, now: Date = Date()) -> Bool {
        account.expiresAt.timeIntervalSince(now) < tokenRefreshThreshold
    }

    public func nextDue(for account: Account) -> Date {
        nextDueAt[account.id] ?? .distantPast
    }

    func increaseBackoff(_ id: String) async {
        let count = (failureCount[id] ?? 0) + 1
        failureCount[id] = count
        let multiplier = pow(2.0, Double(min(count, 4)))
        nextDueAt[id] = await clock().addingTimeInterval(Self.minimumInterval * multiplier)
    }

    func lastValueOr(account: Account, description: String) async -> AccountUsage {
        if let previous = cache[account.id] {
            return AccountUsage(
                session: previous.session,
                weekly: previous.weekly,
                scoped: previous.scoped,
                fetchedAt: previous.fetchedAt,
                staleness: .cached(since: previous.fetchedAt),
                resetCreditsAvailable: previous.resetCreditsAvailable,
                resetCreditId: previous.resetCreditId
            )
        }
        return AccountUsage(
            session: .empty, weekly: .empty, scoped: [],
            fetchedAt: await clock(), staleness: .error(description)
        )
    }

    /// Last known numbers after a 429. For the account Claude Code is using,
    /// the CLI's own `cachedUsageUtilization` wins when it is newer.
    func rateLimitedValue(account: Account) async -> AccountUsage {
        let previous = cache[account.id]
        var base = previous
        if account.provider == .anthropic,
           CLISwitcher.activeClaudeEmail(url: claudeConfigURL)?
               .caseInsensitiveCompare(account.email) == .orderedSame,
           let fromCLI = CLISwitcher.cachedClaudeUsage(url: claudeConfigURL),
           fromCLI.fetchedAt > (previous?.fetchedAt ?? .distantPast) {
            base = fromCLI
        }
        guard let base else {
            return await lastValueOr(account: account, description: "Rate limited. Trying again later.")
        }
        let result = AccountUsage(
            session: base.session,
            weekly: base.weekly,
            scoped: base.scoped,
            fetchedAt: base.fetchedAt,
            staleness: .rateLimited(since: base.fetchedAt),
            resetCreditsAvailable: base.resetCreditsAvailable,
            resetCreditId: base.resetCreditId
        )
        cache[account.id] = result
        return result
    }

    /// Claude accounts the CLI isn't using are polled at a third of the pace,
    /// which keeps the shared usage endpoint under its rate limit.
    func shouldDeferInactiveClaude(_ account: Account, now: Date, interval: TimeInterval) -> Bool {
        guard account.provider == .anthropic,
              cache[account.id] != nil,
              let last = lastAttempt[account.id],
              CLISwitcher.activeClaudeEmail(url: claudeConfigURL)?
                  .caseInsensitiveCompare(account.email) != .orderedSame
        else { return false }
        return now.timeIntervalSince(last) < max(interval, Self.minimumInterval) * 3
    }

    /// An account whose 5-hour or weekly window is used up stays that way until
    /// the window resets, so there is nothing to ask the provider. Returns the
    /// last known numbers (the countdown comes from their `resetsAt`) while the
    /// block lasts, or nil once it is over or the account isn't blocked.
    func exhaustedValue(account: Account, now: Date) -> AccountUsage? {
        guard let known = cache[account.id] else { return nil }
        let blockedUntil = [known.session, known.weekly]
            .filter { $0.percent >= 100 }
            .compactMap(\.resetsAt)
            .max()
        guard let blockedUntil, blockedUntil > now else { return nil }
        return AccountUsage(
            session: known.session,
            weekly: known.weekly,
            scoped: known.scoped,
            fetchedAt: known.fetchedAt,
            staleness: .fresh,
            resetCreditsAvailable: known.resetCreditsAvailable,
            resetCreditId: known.resetCreditId
        )
    }
}
