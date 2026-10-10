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
    public static let anthropicAuthorizeURL = URL(string: "https://claude.com/cai/oauth/authorize")!
    public static let anthropicTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    public static let anthropicClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    /// The set a real Claude Code sign-in asks for, confirmed 2026-09-05 by
    /// comparing against a working CLI token.
    public static let anthropicScopes = "user:file_upload user:inference user:mcp_servers user:profile user:sessions:claude_code"
    public static let anthropicBeta = "oauth-2025-04-20"
    /// Without a header that impersonates the CLI, the usage endpoint answers
    /// with a hard 429.
    public static let anthropicUserAgent = ClaudeCLIUserAgent.current

    public static let codexUsageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    public static let codexResetCreditsURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    public static let codexResetConsumeURL = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume")!
    public static let openAIAuthorizeURL = URL(string: "https://auth.openai.com/oauth/authorize")!
    public static let openAITokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    public static let openAIClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    public static let openAIRedirectURI = "http://localhost:1455/auth/callback"
    public static let openAIPort: UInt16 = 1455
    public static let openAIScopes = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    /// The scope sent when refreshing a token.
    public static let openAIRefreshScope = "openid profile email"

    /// Gemini OAuth client parameters.
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
    public static let updateFeedURL: URL? = URL(string: "https://raw.githubusercontent.com/tomaszboloz/FuelSwitch-AI/main/appcast.xml")
}
