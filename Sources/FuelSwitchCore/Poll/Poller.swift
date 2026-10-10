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
        clock: @escaping @Sendable () async -> Date = { Date() }
    ) {
        self.store = store
        self.providers = providers
        self.oauth = oauth
        self.codexAuthURL = codexAuthURL
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
}
