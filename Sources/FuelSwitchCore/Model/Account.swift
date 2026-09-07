import Foundation

public enum Provider: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openai
    case gemini

    /// The products' own names. Anthropic's CLI is Claude Code; OpenAI's is
    /// Codex; Google's is Gemini CLI.
    public var displayName: String {
        switch self {
        case .anthropic: "Claude"
        case .openai: "Codex"
        case .gemini: "Gemini"
        }
    }

    public var menuBarLabel: String {
        switch self {
        case .anthropic: "Claude"
        case .openai: "Codex"
        case .gemini: "Gemini"
        }
    }

    public var monogram: String {
        switch self {
        case .anthropic: "CC"
        case .openai: "CX"
        case .gemini: "GM"
        }
    }
}

extension Provider: Identifiable {
    public var id: String { rawValue }
}

public struct Account: Codable, Sendable, Equatable, Identifiable {
    public let provider: Provider
    /// The account's own address, as its provider reports it. This is both the
    /// identity and the label: a second, user-invented name would identify
    /// nothing the email does not already say.
    public var email: String
    public var plan: String?
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    /// Codex only — goes into the `ChatGPT-Account-Id` header.
    public var accountId: String?
    /// Set when a token refresh came back with `invalid_grant`.
    public var needsReauth: Bool
    /// The organisation the token authorised against, as the provider named it.
    /// Only used to explain a refusal: an account can belong to several, and
    /// only the one holding the subscription reports usage.
    public var organizationName: String?
    /// Whether the login holds a Claude subscription, as opposed to only API
    /// access. Used to tell "the sign-in picked the wrong organisation" apart
    /// from "there is no subscription here to report".
    public var hasSubscription: Bool

    /// Cached raw idToken (useful for restoring auth in Codex CLI).
    public var idToken: String?

    /// An account is identified by provider plus email, so signing the same
    /// account in again overwrites the existing entry rather than adding a
    /// duplicate.
    public var id: String { "\(provider.rawValue):\(email.lowercased())" }

    public init(
        provider: Provider,
        email: String,
        plan: String? = nil,
        accessToken: String = "",
        refreshToken: String = "",
        expiresAt: Date = .distantPast,
        accountId: String? = nil,
        needsReauth: Bool = false,
        organizationName: String? = nil,
        hasSubscription: Bool = false,
        idToken: String? = nil
    ) {
        self.provider = provider
        self.email = email
        self.plan = plan
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.accountId = accountId
        self.needsReauth = needsReauth
        self.organizationName = organizationName
        self.hasSubscription = hasSubscription
        self.idToken = idToken
    }
}

extension Account: CustomStringConvertible {
    public var description: String {
        let maskedAccess = accessToken.isEmpty ? "<none>" : "\(accessToken.prefix(4))...redacted"
        let maskedRefresh = refreshToken.isEmpty ? "<none>" : "\(refreshToken.prefix(4))...redacted"
        return "Account(provider: \(provider.rawValue), email: \(email), plan: \(plan ?? "none"), access: \(maskedAccess), refresh: \(maskedRefresh), needsReauth: \(needsReauth))"
    }
}
