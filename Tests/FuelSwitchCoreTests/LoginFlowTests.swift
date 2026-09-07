import Testing
import Foundation
@testable import FuelSwitchCore

private func temporaryLoginDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private struct StubOAuth: OAuthProvider {
    let port: UInt16
    var accessToken: String = "a"
    var requiredPort: UInt16 { 0 }
    func authorizationURL(pkce: PKCE, redirectURI: String) -> URL {
        URL(string: "http://127.0.0.1:\(port)/callback?code=CODE&state=\(pkce.state)")!
    }
    func exchange(code: String, pkce: PKCE, redirectURI: String) async throws -> Tokens {
        #expect(code == "CODE")
        return Tokens(accessToken: accessToken, refreshToken: "r", expiresAt: Date().addingTimeInterval(3600))
    }
    func refresh(refreshToken: String) async throws -> Tokens {
        Tokens(accessToken: accessToken, refreshToken: refreshToken, expiresAt: Date())
    }
}

// The test deliberately uses the `.anthropic` provider, because that one
// listens on any free port. Codex requires the fixed port 1455, which would
// make the test depend on whether a `codex login` happens to be running. An
// Anthropic identity comes from a separate profile call, so we substitute it
// through `profileFactory` rather than hitting the real API from a unit test.
@Test func anAnthropicSignInStoresTheAccountFromTheProfileData() async throws {
    let directory = try temporaryLoginDirectory()
    let store = AccountStore(directory: directory)

    // The browser is replaced by a request straight to the redirect address.
    let flow = LoginFlow(store: store) { url in
        Task { _ = try? await URLSession.shared.data(from: url) }
    }
    let account = try await flow.logIn(
        provider: .anthropic,
        providerFactory: { port in StubOAuth(port: port) },
        profileFactory: { _ in AnthropicProfile(email: "new@account.pl", plan: "default_claude_max_20x") }
    )

    #expect(account.email == "new@account.pl")
    #expect(account.plan == "default_claude_max_20x")
    #expect(account.accountId == nil)
    #expect(try store.load().count == 1)
}

/// Signing the same account in twice must not produce two entries. The
/// identity is provider:email and the email comes from the provider, so the
/// second sign-in cannot help but land on the same identity — it overwrites the
/// first with fresh tokens.
@Test func signingInTheSameAccountTwiceStoresOneEntryWithFreshTokens() async throws {
    let store = AccountStore(directory: try temporaryLoginDirectory())
    let flow = LoginFlow(store: store) { url in
        Task { _ = try? await URLSession.shared.data(from: url) }
    }

    _ = try await flow.logIn(
        provider: .anthropic,
        providerFactory: { port in StubOAuth(port: port, accessToken: "first") },
        profileFactory: { _ in AnthropicProfile(email: "same@account.pl", plan: nil) }
    )
    _ = try await flow.logIn(
        provider: .anthropic,
        providerFactory: { port in StubOAuth(port: port, accessToken: "second") },
        profileFactory: { _ in AnthropicProfile(email: "same@account.pl", plan: nil) }
    )

    let saved = try store.load()
    #expect(saved.count == 1)
    #expect(saved[0].email == "same@account.pl")
    #expect(saved[0].accessToken == "second")
}

@Test func aProfileFailureStoresNoAccountWithAnInventedIdentity() async throws {
    let directory = try temporaryLoginDirectory()
    let store = AccountStore(directory: directory)
    let flow = LoginFlow(store: store) { url in
        Task { _ = try? await URLSession.shared.data(from: url) }
    }

    await #expect(throws: AnthropicProfileError.self) {
        _ = try await flow.logIn(
            provider: .anthropic,
            providerFactory: { port in StubOAuth(port: port) },
            profileFactory: { _ in throw AnthropicProfileError.responseWithoutEmail }
        )
    }
    #expect(try store.load().isEmpty)
}

// Uses the production two-argument entry point (`logIn(provider:alias:)`) with
// no factory at all — exercising the sign-in error the user can most easily fix
// themselves: Codex's port 1455 being occupied. We occupy the port ourselves in
// the same test function, so the outcome does not depend on whether a
// `codex login` happens to be running in the background.
@Test func anOccupiedCodexPortGivesAPortInUseError() async throws {
    let blocker = CallbackListener(port: FuelSwitchConstants.openAIPort)
    _ = try blocker.start(expectedState: "x", expectedPath: "/auth/callback")
    defer { blocker.stop() }

    let store = AccountStore(directory: try temporaryLoginDirectory())
    let flow = LoginFlow(store: store) { _ in }

    await #expect(throws: OAuthError.portInUse(FuelSwitchConstants.openAIPort)) {
        _ = try await flow.logIn(provider: .openai)
    }
}

// MARK: - F8: an incomplete Codex identity must throw rather than substitute
// stand-in values.
//
// We test `accountIdentity` directly (not through the full `logIn`), because
// for `.openai` `logIn` always binds the REAL port 1455 (see the comment above
// `anOccupiedCodexPortGivesAPortInUseError`) — and the same port is occupied by
// that test in this same file, which under parallel test execution would give
// false failures unrelated to the logic under test. `accountIdentity` is a pure
// function of its inputs, so this way the test is both faster and
// deterministic.

@Test func aCodexIdentityWithoutAnEmailInTheIdTokenThrows() async throws {
    let flow = LoginFlow(store: AccountStore(directory: try temporaryLoginDirectory())) { _ in }
    let payload = Data(#"""
    {"https://api.openai.com/auth":{"chatgpt_account_id":"acc-1"}}
    """#.utf8).base64URLEncoded
    let tokens = Tokens(accessToken: "a", refreshToken: "r", expiresAt: Date(), idToken: "h.\(payload).s")

    await #expect(throws: OAuthError.incompleteCodexIdentity) {
        _ = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
            AnthropicProfile(email: "unused", plan: nil)
        }
    }
}

@Test func aCodexIdentityWithoutAnAccountIdInTheIdTokenThrows() async throws {
    let flow = LoginFlow(store: AccountStore(directory: try temporaryLoginDirectory())) { _ in }
    let payload = Data(#"{"email":"someone@account.pl"}"#.utf8).base64URLEncoded
    let tokens = Tokens(accessToken: "a", refreshToken: "r", expiresAt: Date(), idToken: "h.\(payload).s")

    await #expect(throws: OAuthError.incompleteCodexIdentity) {
        _ = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
            AnthropicProfile(email: "unused", plan: nil)
        }
    }
}

@Test func aCodexIdentityWithNoIdTokenAtAllThrows() async throws {
    let flow = LoginFlow(store: AccountStore(directory: try temporaryLoginDirectory())) { _ in }
    let tokens = Tokens(accessToken: "a", refreshToken: "r", expiresAt: Date(), idToken: nil)

    await #expect(throws: OAuthError.incompleteCodexIdentity) {
        _ = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
            AnthropicProfile(email: "unused", plan: nil)
        }
    }
}

// MARK: - F4 / F-C: cancelling a sign-in must release the listening port

/// Carries the port bound by `CallbackListener` from the synchronous
/// `providerFactory` (called inside `LoginFlow.logIn` right after
/// `listener.start()`, before `openURL`) to the asynchronous test, which has to
/// wait until the listener is actually up before cancelling the task.
private actor PortSignal {
    private var port: UInt16?
    private var continuation: CheckedContinuation<UInt16, Never>?

    func set(_ value: UInt16) {
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: value)
        } else {
            port = value
        }
    }

    func wait() async -> UInt16 {
        if let port { return port }
        return await withCheckedContinuation { continuation = $0 }
    }
}

private struct TestTimedOut: Error {}

private func withTestTimeout<T: Sendable>(
    _ seconds: Double = 5,
    _ work: @escaping @Sendable () async -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TestTimedOut()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

// F4 introduced sign-in cancellation precisely in order to release the port —
// this test checks exactly that behaviour, on the same path where F-B lives
// (concurrent `stop()` from `onCancel` and from the `defer` in
// `awaitCodeWithTimeout`). Deliberately `.anthropic`, not `.openai`: Anthropic
// listens on any free port assigned by the system, so the test does not depend
// on Codex's port 1455 happening to be free.
@Test func cancellingASignInReleasesTheListeningPort() async throws {
    let store = AccountStore(directory: try temporaryLoginDirectory())
    let signal = PortSignal()

    let flow = LoginFlow(store: store) { _ in
        // The browser is never really opened — by this point the listener is
        // already up (see the order in `LoginFlow.logIn`).
    }

    let task = Task {
        try await flow.logIn(
            provider: .anthropic,
            providerFactory: { port in
                Task { await signal.set(port) }
                return StubOAuth(port: port)
            }
        )
    }

    let port = try await withTestTimeout { await signal.wait() }

    task.cancel()
    await #expect(throws: (any Error).self) {
        _ = try await task.value
    }

    // If `stop()` really did release the `NWListener` — and exactly once — a
    // fresh `CallbackListener` can bind the same port. `NWListener.cancel()`
    // releases the socket asynchronously inside Network.framework, so a few
    // attempts spaced slightly apart guard the test against an incidental
    // failure caused by system timing rather than by the bug under test: the
    // F-B defect (two concurrent non-atomic writes of `nil`) would leave the
    // port permanently unavailable or crash the process, not delay it briefly.
    var boundPort: UInt16?
    for attempt in 0..<30 where boundPort == nil {
        if attempt > 0 { try? await Task.sleep(nanoseconds: 50_000_000) }
        let probe = CallbackListener(port: port)
        if let bound = try? probe.start(expectedState: "probe", expectedPath: "/callback") {
            boundPort = bound
            probe.stop()
        }
    }
    #expect(boundPort == port)
}

@Test func aCompleteCodexIdTokenYieldsTheFullIdentity() async throws {
    let flow = LoginFlow(store: AccountStore(directory: try temporaryLoginDirectory())) { _ in }
    let payload = Data(#"""
    {"email":"complete@account.pl","https://api.openai.com/auth":{"chatgpt_account_id":"acc-9","chatgpt_plan_type":"pro"}}
    """#.utf8).base64URLEncoded
    let tokens = Tokens(accessToken: "a", refreshToken: "r", expiresAt: Date(), idToken: "h.\(payload).s")

    let identity = try await flow.accountIdentity(provider: .openai, tokens: tokens) { _ in
        AnthropicProfile(email: "unused", plan: nil)
    }

    #expect(identity.email == "complete@account.pl")
    #expect(identity.accountId == "acc-9")
    #expect(identity.plan == "pro")
}


