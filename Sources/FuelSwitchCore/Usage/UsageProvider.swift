import Foundation

public enum FuelSwitchConstants {
    public static let anthropicUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    public static let anthropicProfileURL = URL(string: "https://api.anthropic.com/api/oauth/profile")!
    /// The subscription sign-in, not the API console one. Claude Code carries
    /// BOTH — `CONSOLE_AUTHORIZE_URL` on platform.claude.com and
    /// `CLAUDE_AI_AUTHORIZE_URL` here — and they lead to different places: the
    /// console flow pairs with the `org:create_api_key` scope and finishes on
    /// platform.claude.com/buy_credits, while this one redirects to
    /// claude.ai/oauth/authorize and issues a token for the organisation that
    /// holds the subscription.
    ///
    /// Using the console URL is what put tokens on an API organisation, which
    /// the usage endpoint then refused with
    /// `oauth_not_allowed_for_organization`. The scopes were already the
    /// subscription set; only the address was wrong.
    public static let anthropicAuthorizeURL = URL(string: "https://claude.com/cai/oauth/authorize")!
    public static let anthropicTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    public static let anthropicClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    /// The set a real Claude Code sign-in asks for, confirmed 2026-09-05 by
    /// comparing against a working CLI token. The previous value included
    /// `org:create_api_key` and came from the `claude setup-token` flow, which
    /// mints API keys — with such a token `/api/oauth/usage` answers 403 and
    /// the app never sees any data.
    public static let anthropicScopes = "user:file_upload user:inference user:mcp_servers user:profile user:sessions:claude_code"
    public static let anthropicBeta = "oauth-2025-04-20"
    /// Without a header that impersonates the CLI, the usage endpoint answers
    /// with a hard 429.
    public static let anthropicUserAgent = "claude-cli/2.1.260 (external, cli)"

    public static let codexUsageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    public static let codexResetCreditsURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    public static let codexResetConsumeURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume")!
    public static let openAIAuthorizeURL = URL(string: "https://auth.openai.com/oauth/authorize")!
    public static let openAITokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    public static let openAIClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let openAIRedirectURI = "http://localhost:1455/auth/callback"
    public static let openAIPort: UInt16 = 1455
    public static let openAIScopes = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    /// The scope sent when refreshing a token — deliberately narrower than
    /// `openAIScopes`: for a `refresh_token` grant the scope must be a subset
    /// of what was originally granted, so asking for the full authorisation
    /// set can be rejected while this narrower one is always safe. It is
    /// exactly what codex-check sends, and that is known to work.
    public static let openAIRefreshScope = "openid profile email"

    /// Gemini's OAuth client isn't shipped in the repo: unlike Anthropic's and
    /// OpenAI's (published, meant to be embedded in installed apps), this one
    /// is provisioned per-build from your own Google Cloud project. It is read
    /// from `GeminiClientStore` (filled in by the in-app "Connect Gemini"
    /// setup sheet) first, falling back to the `FUELSWITCH_GEMINI_CLIENT_ID` /
    /// `FUELSWITCH_GEMINI_CLIENT_SECRET` environment variables for local
    /// development — or Gemini sign-in stays disabled (`geminiIsConfigured` is
    /// checked before any network call, in `LoginFlow`).
    public static var geminiClientID: String {
        GeminiClientStore.default.load()?.clientID
            ?? ProcessInfo.processInfo.environment["FUELSWITCH_GEMINI_CLIENT_ID"] ?? ""
    }
    public static var geminiClientSecret: String {
        GeminiClientStore.default.load()?.clientSecret
            ?? ProcessInfo.processInfo.environment["FUELSWITCH_GEMINI_CLIENT_SECRET"] ?? ""
    }
    public static var geminiIsConfigured: Bool { !geminiClientID.isEmpty && !geminiClientSecret.isEmpty }
    public static let geminiScopes = "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
    public static let geminiAuthorizeURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    public static let geminiTokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    public static let geminiUserInfoURL = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!

    /// Where the app looks for a newer release.
    public static let latestReleaseURL: URL? = URL(string: "https://api.github.com/repos/tomaszboloz/FuelSwitch-AI/releases/latest")
}

public enum UsageError: Error, Equatable {
    case rateLimited
    case unauthorized
    case unavailableQuota
    /// An Anthropic account can be a subscription and an API Console
    /// organisation at the same time. A token bound to the latter is entirely
    /// valid — the profile endpoint answers normally — but the usage endpoint
    /// refuses it permanently. Adding the account again without changing
    /// organisation produces exactly the same error, so this refusal must not
    /// look like an expired token.
    case organizationNotAllowed
    case http(Int)
}

public protocol UsageProvider: Sendable {
    func fetch(account: Account) async throws -> AccountUsage
}

extension UsageProvider {
    /// Shared mapping from status code to domain error — 429 and 401 have very
    /// different consequences for the schedule than an ordinary failure.
    ///
    /// `body` is needed only for 403: the code alone does not distinguish a
    /// token that needs renewing from an organisation Anthropic will not serve
    /// over OAuth at all.
    func checkStatus(_ response: URLResponse, body: Data = Data()) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300: return
        case 429: throw UsageError.rateLimited
        case 403 where OrganizationRefusal.matches(body): throw UsageError.organizationNotAllowed
        case 401, 403: throw UsageError.unauthorized
        default: throw UsageError.http(http.statusCode)
        }
    }
}

/// Recognises the one error code where signing the same account in again
/// wastes the user's time.
enum OrganizationRefusal {
    static let code = "oauth_not_allowed_for_organization"

    private struct Response: Decodable {
        struct ErrorBody: Decodable {
            struct Details: Decodable { let errorCode: String? }
            let details: Details?
        }
        let error: ErrorBody?
    }

    static func matches(_ body: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(Response.self, from: body) else { return false }
        return response.error?.details?.errorCode == code
    }
}
