import Foundation

/// Detects the currently active account in CLI tools (Claude Code, Codex, Gemini)
/// and allows switching between connected accounts by updating CLI credentials.
public enum CLISwitcher {
    public enum Error: Swift.Error, Equatable {
        case invalidClaudeConfig
        case keychain(OSStatus)
    }

    public static var claudeConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    public static var codexAuthURL: URL {
        codexHome(environment: ProcessInfo.processInfo.environment).appendingPathComponent("auth.json")
    }

    public static func codexHome(environment: [String: String]) -> URL {
        if let path = environment["CODEX_HOME"], !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    public static var geminiActiveAccountURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("google_accounts.json")
    }

    public static var geminiOAuthCredsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("oauth_creds.json")
    }

    /// Returns the email of the active account for a given provider, if available.
    public static func activeEmail(
        for provider: Provider,
        knownAccounts: [Account] = [],
        claudeURL: URL = claudeConfigURL,
        codexURL: URL = codexAuthURL,
        geminiURL: URL = geminiActiveAccountURL
    ) -> String? {
        switch provider {
        case .anthropic: return activeClaudeEmail(url: claudeURL)
        case .openai: return activeCodexEmail(url: codexURL, knownAccounts: knownAccounts)
        case .gemini: return activeGeminiEmail(url: geminiURL, knownAccounts: knownAccounts)
        }
    }

    /// Switches the active CLI account for the given account's provider.
    public static func `switch`(
        to account: Account,
        claudeURL: URL = claudeConfigURL,
        codexURL: URL = codexAuthURL,
        geminiActiveAccountURL: URL = geminiActiveAccountURL,
        geminiOAuthCredsURL: URL = geminiOAuthCredsURL
    ) throws {
        switch account.provider {
        case .anthropic:
            try switchClaude(to: account, url: claudeURL)
        case .openai:
            try switchCodex(to: account, url: codexURL)
        case .gemini:
            try switchGemini(to: account, activeAccountURL: geminiActiveAccountURL, oauthCredsURL: geminiOAuthCredsURL)
        }
    }
}
