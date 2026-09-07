import Foundation

/// Refreshes limit usage for every account, honouring the backoff after errors
/// and renewing OAuth tokens just before they expire.
///
/// The mutable state (`cache`, next due dates, failure counts) is protected by
/// actor isolation — no locks and no `@unchecked Sendable`.
public actor Poller {
    public static let baseInterval: TimeInterval = 300
    public static let minimumInterval: TimeInterval = 60
    public static let tokenRefreshThreshold: TimeInterval = 600

    private let store: AccountStore
    private let providers: [Provider: any UsageProvider]
    private let oauth: [Provider: any OAuthProvider]
    /// The clock, injected from outside — plain `Date()` in production, a
    /// controllable clock in tests, so backoff windows measured in minutes can
    /// be moved without a real `Task.sleep`.
    private let clock: @Sendable () async -> Date
    public private(set) var cache: [String: AccountUsage] = [:]
    private var nextDueAt: [String: Date] = [:]
    private var failureCount: [String: Int] = [:]
    /// When each account was last ATTEMPTED — success or failure alike —
    /// independent of `nextDueAt` (which a forced refresh ignores). This is the
    /// one thing a forced "Check now" may never skip: the hard 60-second floor
    /// below which Anthropic's endpoint answers 429. It has to key on the
    /// ATTEMPT rather than on success — an account that has never succeeded (or
    /// has just started returning 429) would otherwise have a floor of zero and
    /// every forced refresh would hammer it.
    private var lastAttempt: [String: Date] = [:]

    public init(
        store: AccountStore,
        providers: [Provider: any UsageProvider],
        oauth: [Provider: any OAuthProvider] = [:],
        clock: @escaping @Sendable () async -> Date = { Date() }
    ) {
        self.store = store
        self.providers = providers
        self.oauth = oauth
        self.clock = clock
    }

    public func loadCache(_ new: [String: AccountUsage]) {
        cache = new
    }

    /// Clears one account's polling history: its last attempt, its backoff
    /// window and its failure count.
    ///
    /// This is called after an account is signed in again. All of that state
    /// keys on the account id, and that does not change when the account is
    /// re-authenticated, so without clearing it fresh credentials inherit the
    /// penalty earned by failed attempts with the old token — including the
    /// hard 60-second floor, which gagged the account at exactly the moment
    /// the user was checking whether the sign-in had worked. The cache stays:
    /// the last known number still beats an empty row.
    public func forgetState(id: String) {
        lastAttempt[id] = nil
        nextDueAt[id] = nil
        failureCount[id] = nil
    }

    /// A token lives for hours, so it is renewed only just before it expires —
    /// every refresh at Anthropic invalidates the previous refresh token, so
    /// the rarer the better.
    public static func needsTokenRefresh(account: Account, now: Date = Date()) -> Bool {
        account.expiresAt.timeIntervalSince(now) < tokenRefreshThreshold
    }

    /// When an account is next due. An account that has never been queried is
    /// always "already due" — hence `.distantPast` rather than the current
    /// time, which lets this method stay synchronous.
    public func nextDue(for account: Account) -> Date {
        nextDueAt[account.id] ?? .distantPast
    }

    /// `interval` is the gap between refreshes configured by the user (see
    /// `AppModel.intervalSeconds`); it is clamped to `minimumInterval` here
    /// anyway — the 60-second floor holds whether or not the caller (for
    /// instance `AppModel`) remembered to clamp it.
    public func refresh(account: Account, interval: TimeInterval = Poller.baseInterval) async -> AccountUsage {
        var current = account

        if Self.needsTokenRefresh(account: current, now: await clock()), let provider = oauth[account.provider] {
            do {
                let tokens = try await provider.refresh(refreshToken: current.refreshToken)
                current.accessToken = tokens.accessToken
                current.refreshToken = tokens.refreshToken
                current.expiresAt = tokens.expiresAt
                current.needsReauth = false
                do {
                    try store.upsert(current)
                } catch {
                    // Anthropic rotates the refresh token on EVERY refresh, so
                    // the old one is already dead on the server. Failing to
                    // store the new one means that in a moment we will hold no
                    // working token at all, which is itself a failure deserving
                    // backoff and a diagnosis in the row — not a silent `try?`
                    // that would hide it.
                    await increaseBackoff(account.id)
                    return await lastValueOr(account: account, description: "Could not save the renewed token.")
                }
            } catch OAuthError.invalidGrant {
                current.needsReauth = true
                try? store.upsert(current)
                return await lastValueOr(account: account, description: "Rejected by the provider. Add this account again to renew it.")
            } catch {
                await increaseBackoff(account.id)
                return await lastValueOr(account: account, description: "Could not renew the token.")
            }
        }

        guard let provider = providers[account.provider] else {
            return await lastValueOr(account: account, description: "No client for this provider.")
        }

        // The attempt is recorded BEFORE calling `fetch`, so that no path —
        // neither success nor any of the failure branches below — can query the
        // usage endpoint without noting it for the hard 60-second floor in
        // `refreshAll`.
        let now = await clock()
        lastAttempt[account.id] = now

        do {
            let result = try await provider.fetch(account: current)
            cache[account.id] = result
            failureCount[account.id] = 0
            nextDueAt[account.id] = now.addingTimeInterval(max(interval, Self.minimumInterval))
            return result
        } catch UsageError.rateLimited {
            await increaseBackoff(account.id)
            return await lastValueOr(account: account, description: "Rate limited. Trying again later.")
        } catch UsageError.organizationNotAllowed {
            // The token works — it is the organisation it bound to that does
            // not report usage. We do not set `needsReauth`, because "sign in
            // again" would send the user back for the same error; what is more,
            // we CLEAR that flag if an earlier rejection left it set. It means
            // "dead token", and this one is alive — left in place it would hide
            // the one message in the row that says what to actually change.
            if current.needsReauth {
                var cleared = current
                cleared.needsReauth = false
                try? store.upsert(cleared)
            }
            await increaseBackoff(account.id)
            let named = account.organizationName.map { "\"\($0)\"" } ?? "This organisation"
            // Two very different situations answer with the same 403, and the
            // user can only act on one of them.
            let description = account.hasSubscription
                ? "\(named) bills per token and reports no subscription limits. This login does have a subscription — the sign-in page put the token on the wrong organisation, and only that page can choose."
                : "\(named) has no Claude subscription to report — it is an API organisation."
            return await lastValueOr(account: account, description: description)
        } catch UsageError.unauthorized {
            // 401 and 403 from the usage endpoint mean the same thing: this
            // token will never start working. Patient retrying achieves
            // nothing — the account has to be signed in again, and the row has
            // to say so.
            var flagged = current
            flagged.needsReauth = true
            try? store.upsert(flagged)
            await increaseBackoff(account.id)
            return await lastValueOr(account: account, description: "Rejected by the provider. Add this account again to renew it.")
        } catch {
            await increaseBackoff(account.id)
            return await lastValueOr(account: account, description: "No connection.")
        }
    }

    /// Checks one account on demand — the per-account refresh button.
    ///
    /// It behaves like "Check now" narrowed to a single account: the backoff
    /// window is ignored, because the user asked for this one explicitly, and
    /// the failure counter is cleared. The hard 60-second floor since the last
    /// ATTEMPT still holds, for the same reason it holds for the button that
    /// refreshes everything — Anthropic answers 429 below that window no matter
    /// who asked.
    public func refreshOne(
        account: Account,
        interval: TimeInterval = Poller.baseInterval
    ) async -> AccountUsage {
        let now = await clock()
        if let last = lastAttempt[account.id], now.timeIntervalSince(last) < Self.minimumInterval {
            return await lastValueOr(
                account: account,
                description: "Checked moments ago. Waiting before the next one."
            )
        }
        failureCount[account.id] = 0
        return await refresh(account: account, interval: interval)
    }

    /// Requests are spread out in time so that seventeen accounts do not hit
    /// both APIs in the same second — and accounts still inside a backoff
    /// window are skipped entirely, because Anthropic's endpoint rate-limits
    /// hard and repeating requests at the same rhythm after a 429 would only
    /// dig the hole deeper.
    ///
    /// `forced` is "Check now": it clears the failure counter and IGNORES
    /// `nextDueAt` (and therefore the backoff window) for every account —
    /// otherwise the button, pressed between two automatic cycles, would query
    /// no accounts at all and return nothing but cached values marked stale,
    /// without changing a single number. The one thing forcing may not
    /// skip is the hard 60-second floor measured from that particular
    /// account's LAST ATTEMPT (success or failure): Anthropic answers 429 below
    /// that window regardless of who asked for the refresh and regardless of
    /// whether the previous attempt succeeded. The failure counter is cleared
    /// only for the accounts this pass actually queries — an account rejected
    /// by the 60-second floor keeps its counter, otherwise a user pressing the
    /// button now and then would pin every failing account forever to the
    /// shallowest backoff step.
    ///
    /// `onResult`, when given, is called after each account rather than after
    /// the whole series — which lets the caller (see `AppModel`) publish
    /// results incrementally instead of holding the panel empty for the
    /// duration of all seventeen requests. Marked `@MainActor`, because
    /// the only caller is the UI, which has to update its state on the main
    /// actor anyway.
    public func refreshAll(
        interval: TimeInterval = Poller.baseInterval,
        forced: Bool = false,
        onResult: (@MainActor @Sendable (String, AccountUsage) -> Void)? = nil
    ) async -> [String: AccountUsage] {
        let accounts = (try? store.load()) ?? []
        let now = await clock()
        var results: [String: AccountUsage] = [:]
        var previousWasQueried = false

        for account in accounts {
            if forced {
                if let last = lastAttempt[account.id], now.timeIntervalSince(last) < Self.minimumInterval {
                    let result = await lastValueOr(account: account, description: "Checked moments ago. Waiting before the next one.")
                    results[account.id] = result
                    await onResult?(account.id, result)
                    continue
                }
                failureCount[account.id] = 0
            } else if nextDue(for: account) > now {
                let result = await lastValueOr(account: account, description: "Waiting out the backoff after an error.")
                results[account.id] = result
                await onResult?(account.id, result)
                continue
            }
            if previousWasQueried {
                try? await Task.sleep(for: .milliseconds(400))
            }
            previousWasQueried = true
            let result = await refresh(account: account, interval: interval)
            results[account.id] = result
            await onResult?(account.id, result)
        }
        return results
    }

    private func increaseBackoff(_ id: String) async {
        let count = (failureCount[id] ?? 0) + 1
        failureCount[id] = count
        let multiplier = pow(2.0, Double(min(count, 4)))
        nextDueAt[id] = await clock().addingTimeInterval(Self.minimumInterval * multiplier)
    }

    /// An empty window says nothing, while a stale number with a note says
    /// everything — so on an error or a skip (backoff) we fall back to the last
    /// known value, and only show the error when there is none.
    private func lastValueOr(account: Account, description: String) async -> AccountUsage {
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
