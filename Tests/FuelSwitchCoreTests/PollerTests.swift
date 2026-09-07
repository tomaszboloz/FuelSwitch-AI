import Testing
import Foundation
@testable import FuelSwitchCore

private struct StubUsage: UsageProvider {
    let result: Result<AccountUsage, Error>
    func fetch(account: Account) async throws -> AccountUsage { try result.get() }
}

private struct StubOAuth: OAuthProvider {
    let requiredPort: UInt16 = 0
    let result: Result<Tokens, Error>

    func authorizationURL(pkce: PKCE, redirectURI: String) -> URL {
        URL(string: "https://example.invalid/authorize")!
    }

    func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens {
        fatalError("unused in the Poller tests")
    }

    func refresh(refreshToken: String) async throws -> Tokens { try result.get() }
}

/// A provider that counts its calls — the evidence that an account inside a
/// backoff window is not queried again by `refreshAll()`.
private actor CountingProvider: UsageProvider {
    private(set) var calls = 0
    let result: Result<AccountUsage, Error>

    init(result: Result<AccountUsage, Error>) {
        self.result = result
    }

    func fetch(account: Account) async throws -> AccountUsage {
        calls += 1
        return try result.get()
    }
}

/// A hand-driven clock for the tests — lets time move past a backoff window
/// without a real `Task.sleep`, which keeps the tests fast and deterministic.
private actor TestClock {
    private var now: Date
    init(_ start: Date = Date()) { now = start }
    func reading() -> Date { now }
    func advance(by interval: TimeInterval) { now = now.addingTimeInterval(interval) }
}

private func usage(_ percent: Double) -> AccountUsage {
    AccountUsage(
        session: LimitWindow(percent: percent, resetsAt: nil, label: "5h"),
        weekly: .empty, scoped: [], fetchedAt: Date(), staleness: .fresh
    )
}

private func account(email: String = "a@b.pl", expiresAt: Date = .distantFuture) -> Account {
    Account(
        provider: .anthropic, email: email,
        accessToken: "tok", refreshToken: "ref", expiresAt: expiresAt
    )
}

@Test func aTokenGoodForHoursNeedsNoRefresh() {
    let now = Date()
    let subject = account(expiresAt: now.addingTimeInterval(3600))
    #expect(Poller.needsTokenRefresh(account: subject, now: now) == false)
}

@Test func aTokenExpiringInFiveMinutesNeedsRefresh() {
    let now = Date()
    let subject = account(expiresAt: now.addingTimeInterval(300))
    #expect(Poller.needsTokenRefresh(account: subject, now: now) == true)
}

@Test func anErrorReturnsTheLastKnownValueMarkedStale() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let poller = Poller(store: store, providers: [.anthropic: StubUsage(result: .success(usage(42)))])
    _ = await poller.refresh(account: account())

    let failing = Poller(store: store, providers: [.anthropic: StubUsage(result: .failure(UsageError.rateLimited))])
    await failing.loadCache(await poller.cache)
    let result = await failing.refresh(account: account())

    #expect(result.session.percent == 42)
    if case .cached = result.staleness {} else { Issue.record("expected a cached value") }
}

@Test func noCacheAndAnErrorGivesAnErrorState() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let poller = Poller(store: store, providers: [.anthropic: StubUsage(result: .failure(UsageError.http(500)))])
    let result = await poller.refresh(account: account())
    if case .error = result.staleness {} else { Issue.record("expected an error state") }
}

@Test func backoffWidensTheGapAfterA429() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.rateLimited))],
        clock: { await clock.reading() }
    )
    let subject = account()

    _ = await poller.refresh(account: subject)

    // The contract of the first backoff step: multiplier 2^1, so the next due
    // date has to land at least `minimumInterval * 2` from the moment the
    // injected clock reports — not "any due date later than an arbitrarily
    // distant past".
    let afterFailure = await poller.nextDue(for: subject)
    let now = await clock.reading()
    #expect(afterFailure.timeIntervalSince(now) >= Poller.minimumInterval * 2)
}

@Test func anAccountInsideItsBackoffWindowIsNotQueriedAgain() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .failure(UsageError.rateLimited))
    let poller = Poller(
        store: store,
        providers: [.anthropic: provider],
        clock: { await clock.reading() }
    )

    // First pass: the account has no due date yet, so it is queried and falls
    // into backoff after the 429.
    _ = await poller.refreshAll()
    #expect(await provider.calls == 1)

    // Second pass moments later: still inside the backoff window, so the
    // provider must not be queried again.
    _ = await poller.refreshAll()
    #expect(await provider.calls == 1)

    // Move the test clock far past the backoff window (without any real
    // waiting) — now a refresh should reach the provider again.
    await clock.advance(by: Poller.minimumInterval * 20)
    _ = await poller.refreshAll()
    #expect(await provider.calls == 2)
}

@Test func aSuccessfulTokenRefreshStoresTheRotatedToken() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    let subject = account(expiresAt: Date().addingTimeInterval(300)) // below the 600s threshold
    try store.upsert(subject)

    let newTokens = Tokens(
        accessToken: "new-access", refreshToken: "new-refresh",
        expiresAt: Date().addingTimeInterval(3600)
    )
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .success(usage(10)))],
        oauth: [.anthropic: StubOAuth(result: .success(newTokens))]
    )

    _ = await poller.refresh(account: subject)

    // We check the store rather than the poller's own state — a lost write
    // means the account is signed out at the next refresh.
    let saved = try store.load()
    #expect(saved.count == 1)
    #expect(saved[0].refreshToken == "new-refresh")
    #expect(saved[0].accessToken == "new-access")
}

@Test func theRotatedTokenIsStoredBeforeTheUsageRequestCanFail() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    let subject = account(expiresAt: Date().addingTimeInterval(300))
    try store.upsert(subject)

    let newTokens = Tokens(
        accessToken: "new-access-2", refreshToken: "new-refresh-2",
        expiresAt: Date().addingTimeInterval(3600)
    )
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.http(500)))],
        oauth: [.anthropic: StubOAuth(result: .success(newTokens))]
    )

    let result = await poller.refresh(account: subject)

    let saved = try store.load()
    #expect(saved.count == 1)
    #expect(saved[0].refreshToken == "new-refresh-2")
    if case .error = result.staleness {} else { Issue.record("expected an error state after the usage fetch failed") }
}

@Test func invalidGrantFlagsOneAccountWithoutBlockingTheOthers() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    let needingReauth = account(email: "expired@b.pl", expiresAt: Date().addingTimeInterval(300))
    let working = account(email: "works@b.pl", expiresAt: .distantFuture)
    try store.upsert(needingReauth)
    try store.upsert(working)

    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .success(usage(55)))],
        oauth: [.anthropic: StubOAuth(result: .failure(OAuthError.invalidGrant))]
    )

    let results = await poller.refreshAll()

    #expect(results[working.id]?.session.percent == 55)

    let saved = try store.load()
    let failedInStore = saved.first { $0.id == needingReauth.id }
    #expect(failedInStore?.needsReauth == true)
    let workingInStore = saved.first { $0.id == working.id }
    #expect(workingInStore?.needsReauth == false)
}

@Test func anUnknownTokenRefreshErrorEngagesBackoff() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    let subject = account(expiresAt: Date().addingTimeInterval(300))
    try store.upsert(subject)

    let clock = TestClock()
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .success(usage(1)))],
        oauth: [.anthropic: StubOAuth(result: .failure(OAuthError.http(500)))],
        clock: { await clock.reading() }
    )

    _ = await poller.refresh(account: subject)

    // Without the call to increaseBackoff the due date would stay unset
    // (`.distantPast`), so the account would be queried on every cycle despite
    // its token refresh still being broken.
    let due = await poller.nextDue(for: subject)
    let now = await clock.reading()
    #expect(due.timeIntervalSince(now) >= Poller.minimumInterval * 2)
}

// MARK: - F3: forced refresh ("Check now")

@Test func aForcedRefreshQueriesAnAccountInsideItsNormalWindow() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .success(usage(10)))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    // First pass: the account has no due date yet, so it is queried; with an
    // interval of 1200s the next due date lands far in the future.
    _ = await poller.refreshAll(interval: 1200)
    #expect(await provider.calls == 1)

    // Move the clock a little — past the hard 60s floor since the last
    // success, but still well before the next ordinary cycle.
    await clock.advance(by: 200)

    // An ordinary (unforced) refresh skips the account — its due date has not
    // arrived.
    _ = await poller.refreshAll(interval: 1200)
    #expect(await provider.calls == 1)

    // A forced refresh ignores the due date and queries anyway — exactly what
    // "Check now" is expected to do.
    _ = await poller.refreshAll(interval: 1200, forced: true)
    #expect(await provider.calls == 2)
}

@Test func aForcedRefreshRespectsTheHard60sFloorSinceTheLastAttempt() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .success(usage(10)))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    _ = await poller.refreshAll()
    #expect(await provider.calls == 1)

    // Only 20s since the last attempt — below the hard 60s floor.
    await clock.advance(by: 20)
    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 1)

    // Past the floor (20 + 50 = 70s > 60s), a forced refresh queries again.
    await clock.advance(by: 50)
    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 2)
}

// MARK: - F-A: the 60s floor must key on the ATTEMPT, not on success

@Test func aForcedRefreshRespectsThe60sFloorForAnAccountThatNeverSucceeded() async throws {
    // Reproduces F-A exactly as the gap was found: an account that has NEVER
    // succeeded (freshly added, DNS down, endpoint already answering 429) — a
    // gate keyed on "the last success" would never fire, because no such entry
    // would exist, so every forced refresh would hammer it with no floor at
    // all. No clock movement between the two forced refreshes — precisely the
    // scenario in which `AppModel.startLogin` triggers a check after each of
    // eleven consecutive Codex sign-ins.
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .failure(UsageError.rateLimited))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 1)

    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 1)
}

@Test func forcedPressesRejectedByTheFloorDoNotResetTheBackoffDepth() async throws {
    // The second half of F-A: the old code cleared the failure count on EVERY
    // forced pass, even for accounts rejected by the 60s floor — that is, not
    // queried at all in that pass. The effect: a user pressing "Check now" now
    // and then on a failing account reset the backoff depth without sending a
    // single request, so the next REAL (automatic) failure always used
    // multiplier 2^1 instead of escalating — the account was pinned forever to
    // the shallowest step. (Clearing the counter for an account the pass DOES
    // query is unchanged — that is the intended F3 behaviour, covered by
    // `aForcedRefreshClearsTheFailureCount` below.)
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .failure(UsageError.rateLimited))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    // Two REAL, automatic failures build a backoff depth of 2.
    _ = await poller.refreshAll()
    #expect(await provider.calls == 1)
    await clock.advance(by: Poller.minimumInterval * 4) // comfortably past the 2^1 due date
    _ = await poller.refreshAll()
    #expect(await provider.calls == 2)

    // Several forced presses inside the 60s window after that second failure —
    // the floor rejects them and the provider is never asked.
    await clock.advance(by: 10)
    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 2)
    await clock.advance(by: 20)
    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 2)

    // Move the clock past the 60s floor AND past the established backoff due
    // date (multiplier 2^2 = 240s from the second failure), so an ordinary
    // automatic cycle queries again and fails again.
    await clock.advance(by: Poller.minimumInterval * 5)
    _ = await poller.refreshAll()
    #expect(await provider.calls == 3)

    // Had the forced presses rejected by the floor cleared the counter along
    // the way, this third failure would use multiplier 2^1 (a due date 120s
    // out). Since the counter survived untouched (2, now 3), it is 2^3 (480s
    // out) — a threshold of 6*60s = 360s tells the two cases apart
    // unambiguously.
    let now = await clock.reading()
    let due = await poller.nextDue(for: account())
    #expect(due.timeIntervalSince(now) >= Poller.minimumInterval * 6)
}

@Test func aForcedRefreshClearsTheFailureCount() async throws {
    // An account deep in backoff after a run of 429s — without clearing the
    // failure count the next ordinary failure after a forced refresh would drop
    // straight into an even deeper multiplier instead of starting over.
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .failure(UsageError.rateLimited))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    _ = await poller.refreshAll()
    #expect(await provider.calls == 1)
    await clock.advance(by: Poller.minimumInterval * 20)

    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 2)

    let dueAfterSecondFailure = await poller.nextDue(for: account())
    let now = await clock.reading()
    // A second error after the counter was cleared is multiplier 2^1 again, not
    // 2^2 — the due date should not run further out than minimumInterval * 2
    // (with some margin, since the exact value depends only on this step).
    #expect(dueAfterSecondFailure.timeIntervalSince(now) < Poller.minimumInterval * 4)
}

// MARK: - F6: a failed write of the rotated token must not be swallowed

@Test func aFailedRotatedTokenWriteEngagesBackoffButReturnsTheCache() async throws {
    // The store's directory points at a path where an ordinary file sits rather
    // than a directory — `save()` cannot create `accounts.json` there, so every
    // `upsert` fails deterministically.
    let baseDirectory = try temporaryDirectory()
    let fileInsteadOfDirectory = baseDirectory.appendingPathComponent("not-a-directory")
    try Data().write(to: fileInsteadOfDirectory)
    let brokenStore = AccountStore(directory: fileInsteadOfDirectory)

    let subject = account(expiresAt: Date().addingTimeInterval(300)) // below 600s → forces a token refresh
    let newTokens = Tokens(
        accessToken: "new-access", refreshToken: "new-refresh",
        expiresAt: Date().addingTimeInterval(3600)
    )
    let clock = TestClock()
    let poller = Poller(
        store: brokenStore,
        providers: [.anthropic: StubUsage(result: .success(usage(77)))],
        oauth: [.anthropic: StubOAuth(result: .success(newTokens))],
        clock: { await clock.reading() }
    )
    await poller.loadCache([subject.id: usage(30)])

    let result = await poller.refresh(account: subject)

    // The old cached value, because storing the rotated token failed — NOT the
    // new usage figure, which we would never have reached without a stored
    // token.
    #expect(result.session.percent == 30)
    if case .cached = result.staleness {} else {
        Issue.record("expected a cached value after the rotated token failed to store")
    }

    let due = await poller.nextDue(for: subject)
    let now = await clock.reading()
    #expect(due.timeIntervalSince(now) >= Poller.minimumInterval * 2)
}

@Test func rejectedTokenMarksAccountForReauthentication() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.unauthorized))]
    )

    _ = await poller.refresh(account: account())

    let saved = try #require(try store.load().first)
    #expect(saved.needsReauth == true)
}

@Test func rateLimitDoesNotMarkAccountForReauthentication() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.rateLimited))]
    )

    _ = await poller.refresh(account: account())

    let saved = try #require(try store.load().first)
    #expect(saved.needsReauth == false)
}

// MARK: - F12: results published incrementally, not only after the whole series

@MainActor
private final class CollectedResults {
    private(set) var order: [String] = []
    func add(_ id: String) { order.append(id) }
}

@MainActor
@Test func refreshAllPublishesResultsIncrementally() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    let first = account(email: "a@b.pl")
    let second = account(email: "b@b.pl")
    try store.upsert(first)
    try store.upsert(second)
    let poller = Poller(store: store, providers: [.anthropic: StubUsage(result: .success(usage(20)))])

    let collected = CollectedResults()
    let finalResult = await poller.refreshAll(onResult: { id, _ in
        collected.add(id)
    })

    #expect(Set(collected.order) == Set([first.id, second.id]))
    #expect(finalResult.count == 2)
}

private func temporaryDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// The hard 60s floor keys on the account id, so it survives signing in again.
/// An account added right after a failed attempt with the old token was gagged
/// by it for nearly three minutes — at exactly the moment the user is watching
/// to see whether the sign-in did anything.
@Test func signingInAgainUnblocksTheImmediateCheck() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let provider = CountingProvider(result: .success(usage(11)))
    let poller = Poller(store: store, providers: [.anthropic: provider])

    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 1)

    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 1, "the 60s floor must reject the second attempt")

    await poller.forgetState(id: account().id)
    _ = await poller.refreshAll(forced: true)
    #expect(await provider.calls == 2, "fresh credentials lift the floor")
}

/// A refusal at the organisation level is not an ordinary "token expired":
/// adding the same account in the same organisation gives the same error, so
/// the row has to say what specifically to change.
@Test func anOrganizationRefusalExplainsWhatToDo() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.organizationNotAllowed))]
    )

    let result = await poller.refresh(account: account())

    guard case .error(let description) = result.staleness else {
        Issue.record("expected an error state")
        return
    }
    #expect(description.contains("subscription"))
}

/// A login that pays for a subscription and one that only has API access both
/// answer with the same 403, and only the first is worth acting on. The row has
/// to tell them apart.
@Test func anOrganizationRefusalSeparatesAWrongOrgFromNoSubscription() async throws {
    let store = AccountStore(directory: try temporaryDirectory())

    var subscriber = account(email: "subscriber@b.pl")
    subscriber.organizationName = "Some API Team"
    subscriber.hasSubscription = true
    var apiOnly = account(email: "apionly@b.pl")
    apiOnly.organizationName = "Some API Team"
    apiOnly.hasSubscription = false
    try store.upsert(subscriber)
    try store.upsert(apiOnly)

    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.organizationNotAllowed))]
    )

    guard case .error(let forSubscriber) = await poller.refresh(account: subscriber).staleness,
          case .error(let forApiOnly) = await poller.refresh(account: apiOnly).staleness else {
        Issue.record("expected error states")
        return
    }
    #expect(forSubscriber.contains("does have a subscription"))
    #expect(forApiOnly.contains("no Claude subscription"))
}

/// The message is only actionable if it says WHICH organisation was
/// authorised — an account can belong to several, and the user has no other
/// way to tell which login the app actually made.
@Test func anOrganizationRefusalNamesTheOrganization() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    var subject = account()
    subject.organizationName = "Acme API Team"
    try store.upsert(subject)

    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.organizationNotAllowed))]
    )

    let result = await poller.refresh(account: subject)

    guard case .error(let description) = result.staleness else {
        Issue.record("expected an error state")
        return
    }
    #expect(description.contains("Acme API Team"))
}

/// `needsReauth` means "dead token". At an organisation-level refusal the token
/// is alive, so the flag has to go — otherwise the row would show the generic
/// "add the account again", which is exactly the advice that does not work here.
@Test func anOrganizationRefusalClearsTheDeadTokenFlag() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    var toFlag = account()
    toFlag.needsReauth = true
    try store.upsert(toFlag)

    let poller = Poller(
        store: store,
        providers: [.anthropic: StubUsage(result: .failure(UsageError.organizationNotAllowed))]
    )
    _ = await poller.refresh(account: toFlag)

    let saved = try #require(try store.load().first)
    #expect(saved.needsReauth == false)
}

/// The per-account refresh button. It ignores the backoff window, because the
/// user asked for this account by name, but the hard 60-second floor still
/// holds.
@Test func refreshingOneAccountIgnoresBackoffButNotTheFloor() async throws {
    let store = AccountStore(directory: try temporaryDirectory())
    try store.upsert(account())
    let clock = TestClock()
    let provider = CountingProvider(result: .failure(UsageError.rateLimited))
    let poller = Poller(store: store, providers: [.anthropic: provider], clock: { await clock.reading() })

    _ = await poller.refreshOne(account: account())
    #expect(await provider.calls == 1)

    // Deep inside the backoff window, and inside the floor (20s < 60s): refused.
    await clock.advance(by: 20)
    _ = await poller.refreshOne(account: account())
    #expect(await provider.calls == 1)

    // Past the floor (20 + 50 = 70s > 60s) but still inside the backoff window:
    // asking for this one account explicitly gets through.
    await clock.advance(by: 50)
    _ = await poller.refreshOne(account: account())
    #expect(await provider.calls == 2)
}
