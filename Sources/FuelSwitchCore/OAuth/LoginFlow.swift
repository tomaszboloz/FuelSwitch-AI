import Foundation

public enum LoginFlowError: Error, Equatable {
    case providerNotConfigured(Provider)
}

/// Orchestrates sign-in: opens browser at authorization URL, waits for redirect,
/// exchanges code for tokens, and stores account.
public final class LoginFlow: @unchecked Sendable {
    private let store: AccountStore
    private let openURL: (URL) -> Void

    static let loginTimeout: TimeInterval = 300

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

    private static func expectedPath(_ provider: Provider) -> String {
        switch provider {
        case .anthropic: "/callback"
        case .openai: "/auth/callback"
        case .gemini: "/oauth2callback"
        }
    }

    public func logIn(provider: Provider) async throws -> Account {
        try await logIn(
            provider: provider,
            providerFactory: { _ in Self.defaultProvider(provider) }
        )
    }

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
        let pkce = PKCE.generate()
        let listener = CallbackListener(port: template.requiredPort)
        let port = try listener.start(
            expectedState: pkce.state,
            expectedPath: Self.expectedPath(provider)
        )
        defer { listener.stop() }

        let oauth = providerFactory(port)
        let redirect = redirectURI(for: provider, port: port)
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

    private func redirectURI(for provider: Provider, port: UInt16) -> String {
        switch provider {
        case .openai: FuelSwitchConstants.openAIRedirectURI
        case .gemini: "http://127.0.0.1:\(port)\(Self.expectedPath(provider))"
        case .anthropic: "http://localhost:\(port)\(Self.expectedPath(provider))"
        }
    }

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
            return try await group.next()!
        }
    }
}
