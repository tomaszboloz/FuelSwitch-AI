import Foundation

/// Orchestrates one sign-in: opens the browser at the authorisation URL, waits
/// for the redirect, exchanges the code for tokens and stores the new (or
/// overwritten) account.
///
/// The provider factory is injected rather than defaulted, because Anthropic's
/// redirect address contains a port that is only known once the server is
/// running. The version without a factory is a separate, explicitly delegating
/// method — which avoids a pair of overloads with identical labels that Swift
/// would resolve ambiguously.
public final class LoginFlow: @unchecked Sendable {
    private let store: AccountStore
    private let openURL: (URL) -> Void

    public init(store: AccountStore, openURL: @escaping (URL) -> Void) {
        self.store = store
        self.openURL = openURL
    }

    public static func defaultProvider(_ provider: Provider) -> any OAuthProvider {
        switch provider {
        case .anthropic: AnthropicOAuth()
        case .openai: OpenAIOAuth()
        case .gemini: GeminiOAuth()
        }
    }

    /// The redirect path differs between providers — Anthropic uses
    /// `/callback`, Codex `/auth/callback` (see
    /// `FuelSwitchConstants.openAIRedirectURI`), Gemini `/oauth2callback`.
    private static func expectedPath(_ provider: Provider) -> String {
        switch provider {
        case .anthropic: "/callback"
        case .openai: "/auth/callback"
        case .gemini: "/oauth2callback"
        }
    }

    /// A person is signing in through a browser — five minutes is a sensible
    /// upper bound before the attempt counts as abandoned. Without this limit
    /// an abandoned sign-in would hold `CallbackListener` (and therefore the
    /// port — always 1455 for Codex) for the life of the process.
    static let loginTimeout: TimeInterval = 300

    /// The version the app uses.
    public func logIn(provider: Provider) async throws -> Account {
        try await logIn(
            provider: provider,
            providerFactory: { _ in Self.defaultProvider(provider) }
        )
    }

    /// `providerFactory` receives the port we are actually listening on —
    /// Anthropic's redirect address can only be built once the port is known.
    /// `profileFactory` lets tests substitute the `GET /api/oauth/profile` call
    /// (the only extra network request in this flow) without hitting
    /// Anthropic's real API.
    public func logIn(
        provider: Provider,
        providerFactory: (UInt16) -> any OAuthProvider,
        profileFactory: @escaping (String) async throws -> AnthropicProfile = { token in
            try await AnthropicProfileClient().fetch(accessToken: token)
        }
    ) async throws -> Account {
        if provider == .gemini, !FuelSwitchConstants.geminiIsConfigured {
            throw LoginFlowError.providerNotConfigured(provider)
        }

        let template = Self.defaultProvider(provider)

        // The PKCE pair (and therefore `state`) has to exist BEFORE the
        // listener starts: `start` requires `expectedState`, so that it never
        // compares an incoming parameter against an empty string.
        let pkce = PKCE.generate()
        let listener = CallbackListener(port: template.requiredPort)
        let port = try listener.start(
            expectedState: pkce.state,
            expectedPath: Self.expectedPath(provider)
        )
        defer { listener.stop() }

        let oauth = providerFactory(port)
        // The redirect path comes from the SAME `expectedPath` the
        // `CallbackListener` uses to recognise the right request — "/callback"
        // used to be spelled out here again, independently of the function
        // above. Any drift between the two (when adding a new provider, say)
        // would give the real redirect a 404 from the listener, and the sign-in
        let redirect: String
        switch provider {
        case .openai:
            redirect = FuelSwitchConstants.openAIRedirectURI
        case .gemini:
            redirect = "http://127.0.0.1:\(port)\(Self.expectedPath(provider))"
        case .anthropic:
            redirect = "http://localhost:\(port)\(Self.expectedPath(provider))"
        }

        openURL(oauth.authorizationURL(pkce: pkce, redirectURI: redirect))

        let code = try await awaitCodeWithTimeout(listener)
        let tokens = try await oauth.exchange(code: code, pkce: pkce, redirectURI: redirect)

        let identity = try await accountIdentity(provider: provider, tokens: tokens, profileFactory: profileFactory)

        let account = Account(
            provider: provider,
            email: identity.email,
            plan: identity.plan,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: tokens.expiresAt,
            accountId: identity.accountId,
            organizationName: identity.organizationName,
            hasSubscription: identity.hasSubscription,
            idToken: tokens.idToken
        )

        try store.upsert(account)
        return account
    }

    /// Races `listener.waitForCode()` against a timeout instead of awaiting it
    /// forever. The timeout lives here — in `LoginFlow`, around the
    /// `await` — and NOT inside `CallbackListener`: `CallbackListener.stop()`
    /// calls `queue.sync`, and its only calls from Network.framework callbacks
    /// (`newConnectionHandler`, `receive`) already run ON `queue`, so adding
    /// another `stop()` there from a timer fired on that same queue would
    /// deadlock the process. Calling `stop()` from outside — from Swift
    /// Concurrency's cancellation handling, which runs off `queue` — avoids
    /// that entirely, which makes `LoginFlow` the safe place for it.
    ///
    /// `withTaskCancellationHandler` turns task cancellation into an immediate
    /// `listener.stop()`: that is what wakes the suspended
    /// `CheckedContinuation` inside `waitForCode()` (with `.cancelled`), so
    /// holding this task's handle on `AppModel` and cancelling it from "Cancel"
    /// genuinely releases the listener — and therefore the port — instead of
    /// merely hiding the sign-in window.
    private func awaitCodeWithTimeout(_ listener: CallbackListener) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try await listener.waitForCode()
                } onCancel: {
                    listener.stop()
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.loginTimeout))
                throw OAuthError.timedOut
            }
            defer { group.cancelAll() }
            // Exactly one of the two tasks above always returns or throws —
            // `next()` cannot return `nil` on its first call here.
            return try await group.next()!
        }
    }

    struct Identity: Equatable {
        let email: String
        let plan: String?
        let accountId: String?
        var organizationName: String? = nil
        var hasSubscription: Bool = false
    }

    /// Codex carries the whole identity in the `id_token`, so there is no extra
    /// request here. Anthropic returns no
    /// `id_token` — the identity comes solely from `GET /api/oauth/profile`,
    /// and a failure of that request aborts the sign-in rather than storing an
    /// account under an invented identity (an account with the wrong identity
    /// is worse than no account — it can collide with another one or overwrite
    /// the wrong entry).
    ///
    /// The same rule now binds Codex: a missing `email` or `chatgpt_account_id`
    /// in the `id_token` used to produce a stand-in `email: "unknown"` — and
    /// `Account.id` is `provider:email`, so a second such sign-in would
    /// silently overwrite the first, while usage requests would go out without
    /// the required `ChatGPT-Account-Id` header.
    ///
    /// Not public, but not `private` either, so unit tests (through
    /// `@testable import`) can exercise the identity extraction on its own
    /// without going through the whole OAuth flow — and, for Codex, without
    /// binding the real port 1455.
    func accountIdentity(
        provider: Provider,
        tokens: Tokens,
        profileFactory: (String) async throws -> AnthropicProfile
    ) async throws -> Identity {
        switch provider {
        case .anthropic:
            let profile = try await profileFactory(tokens.accessToken)
            return Identity(
                email: profile.email,
                plan: profile.plan,
                accountId: nil,
                organizationName: profile.organizationName,
                hasSubscription: profile.hasSubscription
            )
        case .openai:
            let claims = tokens.idToken.map(JWT.claims) ?? [:]
            let auth = claims["https://api.openai.com/auth"] as? [String: Any]
            guard let email = claims["email"] as? String,
                  let accountId = auth?["chatgpt_account_id"] as? String
            else {
                throw OAuthError.incompleteCodexIdentity
            }
            return Identity(
                email: email,
                plan: auth?["chatgpt_plan_type"] as? String,
                accountId: accountId
            )
        case .gemini:
            if let idToken = tokens.idToken {
                let claims = JWT.claims(idToken)
                if let email = claims["email"] as? String {
                    return Identity(email: email, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
                }
            }
            var request = URLRequest(url: FuelSwitchConstants.geminiUserInfoURL)
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let email = json["email"] as? String {
                return Identity(email: email, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
            }
            if let active = CLISwitcher.activeGeminiEmail() {
                return Identity(email: active, plan: "Gemini CLI", accountId: nil, organizationName: "Google")
            }
            throw OAuthError.incompleteCodexIdentity
        }
    }
}

/// Thrown before any network call when a provider has no usable OAuth
/// client configured — currently only Gemini, whose client id/secret are
/// supplied by whoever builds the app rather than shipped in the repo.
public enum LoginFlowError: Error, Equatable {
    case providerNotConfigured(Provider)
}
