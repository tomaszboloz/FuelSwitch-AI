import Foundation
import Security

/// Detects the currently active account in CLI tools (Claude Code and Codex)
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
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
            .appendingPathComponent("auth.json")
    }

    public static var geminiConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("auth.json")
    }

    // MARK: - Active Account Detection

    /// Returns the email of the active account for a given provider, if available.
    public static func activeEmail(
        for provider: Provider,
        knownAccounts: [Account] = [],
        claudeURL: URL = claudeConfigURL,
        codexURL: URL = codexAuthURL,
        geminiURL: URL = geminiConfigURL
    ) -> String? {
        switch provider {
        case .anthropic:
            return activeClaudeEmail(url: claudeURL)
        case .openai:
            return activeCodexEmail(url: codexURL, knownAccounts: knownAccounts)
        case .gemini:
            return activeGeminiEmail(url: geminiURL, knownAccounts: knownAccounts)
        }
    }

    /// Reads `oauthAccount.emailAddress` from `~/.claude.json`.
    public static func activeClaudeEmail(url: URL = claudeConfigURL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauthAccount = json["oauthAccount"] as? [String: Any],
              let email = oauthAccount["emailAddress"] as? String
        else {
            return nil
        }
        return email
    }

    /// Reads cached usage utilization from `~/.claude.json` if available.
    public static func cachedClaudeUsage(url: URL = claudeConfigURL) -> AccountUsage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cached = json["cachedUsageUtilization"] as? [String: Any],
              let util = cached["utilization"] as? [String: Any]
        else {
            return nil
        }

        let fiveHour = util["five_hour"] as? [String: Any]
        let sevenDay = util["seven_day"] as? [String: Any]

        let sessionPercent = (fiveHour?["utilization"] as? Double) ?? Double((fiveHour?["utilization"] as? Int) ?? 0)
        let weeklyPercent = (sevenDay?["utilization"] as? Double) ?? Double((sevenDay?["utilization"] as? Int) ?? 0)

        let sessionReset = (fiveHour?["resets_at"] as? String).flatMap(AnthropicUsage.date)
        let weeklyReset = (sevenDay?["resets_at"] as? String).flatMap(AnthropicUsage.date)

        let session = LimitWindow(percent: sessionPercent, resetsAt: sessionReset, label: "5 hours")
        let weekly = LimitWindow(percent: weeklyPercent, resetsAt: weeklyReset, label: "Week")

        let fetchedAt: Date
        if let fetchedMs = cached["fetchedAtMs"] as? Double {
            fetchedAt = Date(timeIntervalSince1970: fetchedMs / 1000)
        } else {
            fetchedAt = Date()
        }

        return AccountUsage(
            session: session,
            weekly: weekly,
            scoped: [],
            fetchedAt: fetchedAt,
            staleness: .fresh
        )
    }

    /// Reads active Codex email or account_id from `~/.codex/auth.json`.
    public static func activeCodexEmail(url: URL = codexAuthURL, knownAccounts: [Account] = []) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any]
        else {
            return nil
        }

        // 1. Try reading profile.email from access_token (standard in Codex tokens)
        if let accessToken = tokens["access_token"] as? String {
            let claims = JWT.claims(accessToken)
            if let profile = claims["https://api.openai.com/profile"] as? [String: Any],
               let email = profile["email"] as? String {
                return email
            }
            if let email = claims["email"] as? String {
                return email
            }
        }

        // 2. Try id_token claims
        if let idToken = tokens["id_token"] as? String {
            let claims = JWT.claims(idToken)
            if let profile = claims["https://api.openai.com/profile"] as? [String: Any],
               let email = profile["email"] as? String {
                return email
            }
            if let email = claims["email"] as? String {
                return email
            }
        }

        // 3. Match via account_id from knownAccounts
        if let accountId = tokens["account_id"] as? String {
            if let matched = knownAccounts.first(where: { $0.provider == .openai && $0.accountId == accountId }) {
                return matched.email
            }
        }

        return nil
    }

    /// Reads active Gemini email from `~/.gemini/auth.json`.
    public static func activeGeminiEmail(url: URL = geminiConfigURL, knownAccounts: [Account] = []) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        if let email = json["email"] as? String { return email }
        if let account = json["account"] as? [String: Any], let email = account["email"] as? String { return email }
        return nil
    }

    // MARK: - Account Switching

    /// Switches the active CLI account for the given account's provider.
    public static func `switch`(
        to account: Account,
        claudeURL: URL = claudeConfigURL,
        codexURL: URL = codexAuthURL,
        geminiURL: URL = geminiConfigURL
    ) throws {
        switch account.provider {
        case .anthropic:
            try switchClaude(to: account, url: claudeURL)
        case .openai:
            try switchCodex(to: account, url: codexURL)
        case .gemini:
            try switchGemini(to: account, url: geminiURL)
        }
    }

    /// Updates `~/.gemini/auth.json` with active account credentials.
    public static func switchGemini(to account: Account, url: URL = geminiConfigURL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var dict: [String: Any] = [
            "email": account.email,
            "access_token": account.accessToken,
            "refresh_token": account.refreshToken,
            "expires_at": ISO8601DateFormatter().string(from: account.expiresAt)
        ]
        if let plan = account.plan { dict["plan"] = plan }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data: data, to: url, permissions: 0o600)
    }

    /// Updates `~/.claude.json` and the macOS Keychain credential `Claude Code-credentials`.
    public static func switchClaude(to account: Account, url: URL = claudeConfigURL) throws {
        try switchClaude(to: account, url: url, keychainUpdater: updateClaudeKeychainCredentials)
    }

    static func switchClaude(
        to account: Account,
        url: URL,
        keychainUpdater: (Account) throws -> Void
    ) throws {
        // Keep the public Claude Code account metadata in sync with the
        // credentials stored in the Keychain.  A first switch can happen
        // before Claude Code has created this file, so it must not be skipped.
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var json: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.invalidClaudeConfig
            }
            json = existing
        }

        var oauthAccount = (json["oauthAccount"] as? [String: Any]) ?? [:]
        oauthAccount["emailAddress"] = account.email
        if let organizationName = account.organizationName {
            oauthAccount["organizationName"] = organizationName
        } else {
            oauthAccount.removeValue(forKey: "organizationName")
        }
        json["oauthAccount"] = oauthAccount

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data: updatedData, to: url, permissions: 0o600)

        // The keychain is the credential source used by Claude Code.
        try keychainUpdater(account)
    }

    /// Updates `~/.codex/auth.json` with the account's tokens.
    public static func switchCodex(to account: Account, url: URL = codexAuthURL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var json: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path),
           let existingData = try? Data(contentsOf: url),
           let existing = (try? JSONSerialization.jsonObject(with: existingData)) as? [String: Any] {
            json = existing
        }

        json["auth_mode"] = "chatgpt"

        var tokensDict: [String: Any] = (json["tokens"] as? [String: Any]) ?? [:]
        tokensDict["access_token"] = account.accessToken
        tokensDict["refresh_token"] = account.refreshToken
        if let accountId = account.accountId {
            tokensDict["account_id"] = accountId
        }
        if let idToken = account.idToken {
            tokensDict["id_token"] = idToken
        } else {
            // If the account has no idToken cached, do NOT keep another account's old id_token
            // Only keep it if its claims match this account's email/accountId
            if let oldIdToken = tokensDict["id_token"] as? String {
                let claims = JWT.claims(oldIdToken)
                let email = claims["email"] as? String
                if email?.lowercased() != account.email.lowercased() {
                    tokensDict.removeValue(forKey: "id_token")
                }
            }
        }

        json["tokens"] = tokensDict
        json["last_refresh"] = ISO8601DateFormatter().string(from: Date())

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data: data, to: url, permissions: 0o600)
    }

    // MARK: - Keychain Helper

    private static func updateClaudeKeychainCredentials(account: Account) throws {
        let service = "Claude Code-credentials"
        
        // Read existing credentials from Keychain so we don't wipe out other keys (like mcpOAuth)
        var existingDict: [String: Any] = [:]
        let getQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let getStatus = SecItemCopyMatching(getQuery as CFDictionary, &item)
        guard getStatus == errSecSuccess || getStatus == errSecItemNotFound else {
            throw Error.keychain(getStatus)
        }
        if getStatus == errSecSuccess, let data = item as? Data,
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            existingDict = dict
        }

        existingDict["claudeAiOauth"] = claudeOAuthPayload(
            existing: existingDict["claudeAiOauth"] as? [String: Any] ?? [:],
            account: account
        )

        let updatedData = try JSONSerialization.data(withJSONObject: existingDict)

        if getStatus == errSecSuccess {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: updatedData
            ]
            let status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else { throw Error.keychain(status) }
        } else {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecValueData as String: updatedData
            ]
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            guard status == errSecSuccess else { throw Error.keychain(status) }
        }
    }

    static func claudeOAuthPayload(existing: [String: Any], account: Account) -> [String: Any] {
        var oauth = existing
        oauth["accessToken"] = account.accessToken
        oauth["refreshToken"] = account.refreshToken
        oauth["expiresAt"] = Int64(account.expiresAt.timeIntervalSince1970 * 1000)
        oauth["subscriptionType"] = account.plan ?? "pro"
        oauth["emailAddress"] = account.email

        if let organizationName = account.organizationName {
            oauth["organizationName"] = organizationName
        } else {
            oauth.removeValue(forKey: "organizationName")
        }

        if oauth["scopes"] == nil {
            oauth["scopes"] = [
                "user:file_upload",
                "user:inference",
                "user:mcp_servers",
                "user:profile",
                "user:sessions:claude_code"
            ]
        }

        return oauth
    }

    // MARK: - File I/O Helper

    private static func atomicWrite(data: Data, to url: URL, permissions: Int16) throws {
        let dir = url.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".\(url.lastPathComponent).tmp.\(UUID().uuidString)")

        try data.write(to: tempURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: tempURL.path
        )

        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: url)
        }

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: url.path
        )
    }
}
