import Foundation
import Security
import Darwin

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
        codexHome(environment: ProcessInfo.processInfo.environment).appendingPathComponent("auth.json")
    }

    public static func codexHome(environment: [String: String]) -> URL {
        if let path = environment["CODEX_HOME"], !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    /// The real Gemini CLI's active-account pointer: `{"active": "<email>",
    /// "old": [...]}`. Distinct from `geminiOAuthCredsURL` — this file names
    /// which account is active, it holds no tokens itself.
    public static var geminiActiveAccountURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("google_accounts.json")
    }

    /// The real Gemini CLI's OAuth token cache, in its own field names
    /// (`access_token`/`refresh_token`/`expiry_date`/…). Earlier versions of
    /// this switcher wrote a FuelSwitch-invented `~/.gemini/auth.json` that
    /// the real Gemini CLI never reads, so switching never actually took
    /// effect outside the app.
    public static var geminiOAuthCredsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("oauth_creds.json")
    }

    // MARK: - Active Account Detection

    /// Returns the email of the active account for a given provider, if available.
    public static func activeEmail(
        for provider: Provider,
        knownAccounts: [Account] = [],
        claudeURL: URL = claudeConfigURL,
        codexURL: URL = codexAuthURL,
        geminiURL: URL = geminiActiveAccountURL
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
        guard let data = try? CodexAuthStore(url: url).load(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any]
        else {
            return nil
        }

        // Codex displays identity from the ID token, not the access token.
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

        // Fallback for older FuelSwitch credentials lacking an ID token.
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

        // 3. Match via account_id from knownAccounts
        if let accountId = tokens["account_id"] as? String {
            if let matched = knownAccounts.first(where: { $0.provider == .openai && $0.accountId == accountId }) {
                return matched.email
            }
        }

        return nil
    }

    /// Reads the `active` key from `~/.gemini/google_accounts.json`, the real
    /// Gemini CLI's active-account pointer file.
    public static func activeGeminiEmail(url: URL = geminiActiveAccountURL, knownAccounts: [Account] = []) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json["active"] as? String
    }

    // MARK: - Account Switching

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

    /// Updates the real Gemini CLI's own files: `google_accounts.json` (the
    /// active-account pointer, with the previously active email preserved in
    /// `old`) and `oauth_creds.json` (tokens, in the CLI's own field names —
    /// `expiry_date` is epoch milliseconds, matching what the real CLI writes).
    public static func switchGemini(
        to account: Account,
        activeAccountURL: URL = geminiActiveAccountURL,
        oauthCredsURL: URL = geminiOAuthCredsURL
    ) throws {
        let dir = activeAccountURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var old: [String] = []
        if let data = try? Data(contentsOf: activeAccountURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            old = (json["old"] as? [String]) ?? []
            if let previousActive = json["active"] as? String, previousActive != account.email, !old.contains(previousActive) {
                old.append(previousActive)
            }
        }
        old.removeAll { $0.lowercased() == account.email.lowercased() }
        let accountsDict: [String: Any] = ["active": account.email, "old": old]
        let accountsData = try JSONSerialization.data(withJSONObject: accountsDict, options: [.prettyPrinted, .sortedKeys])

        var credsDict: [String: Any] = [
            "access_token": account.accessToken,
            "refresh_token": account.refreshToken,
            "scope": FuelSwitchConstants.geminiScopes,
            "token_type": "Bearer",
            "expiry_date": Int64(account.expiresAt.timeIntervalSince1970 * 1000)
        ]
        if let idToken = account.idToken { credsDict["id_token"] = idToken }
        let credsData = try JSONSerialization.data(withJSONObject: credsDict, options: [.prettyPrinted, .sortedKeys])
        let previousCreds = FileManager.default.fileExists(atPath: oauthCredsURL.path) ? try Data(contentsOf: oauthCredsURL) : nil
        try FileManager.default.createDirectory(at: oauthCredsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try atomicWrite(data: credsData, to: oauthCredsURL, permissions: 0o600)
        do {
            try atomicWrite(data: accountsData, to: activeAccountURL, permissions: 0o600)
        } catch {
            try restore(previousCreds, at: oauthCredsURL)
            throw error
        }
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

        let previousData = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        var json: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Error.invalidClaudeConfig
            }
            json = existing
        }

        var oauthAccount: [String: Any] = [:]
        oauthAccount["emailAddress"] = account.email
        if let organizationName = account.organizationName {
            oauthAccount["organizationName"] = organizationName
        } else {
            oauthAccount.removeValue(forKey: "organizationName")
        }
        json["oauthAccount"] = oauthAccount
        json.removeValue(forKey: "cachedUsageUtilization")

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data: updatedData, to: url, permissions: 0o600)

        // The keychain is the credential source used by Claude Code.
        do {
            try keychainUpdater(account)
        } catch {
            try restore(previousData, at: url)
            throw error
        }
    }

    /// Updates `~/.codex/auth.json` with the account's tokens.
    public static func switchCodex(to account: Account, url: URL = codexAuthURL) throws {
        try CodexAuthStore(url: url).save(Self.codexAuthData(for: account))
    }

    public static func validateCodexSwitch(to account: Account, url: URL = codexAuthURL) throws {
        _ = try codexAuthData(for: account)
        _ = try CodexAuthStore(url: url).mode()
    }

    /// Adopt tokens rotated by Codex itself, but only for this exact identity.
    static func newerCodexCredentials(for account: Account, url: URL) throws -> Account? {
        guard let data = try CodexAuthStore(url: url).load(),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["auth_mode"] as? String == "chatgpt",
              let tokens = json["tokens"] as? [String: String],
              tokens["account_id"] == account.accountId,
              let access = tokens["access_token"], let refresh = tokens["refresh_token"],
              let idToken = tokens["id_token"],
              let expiry = JWT.claims(access)["exp"] as? Double,
              expiry > account.expiresAt.timeIntervalSince1970 else { return nil }
        var updated = account
        updated.accessToken = access
        updated.refreshToken = refresh
        updated.idToken = idToken
        updated.expiresAt = Date(timeIntervalSince1970: expiry)
        updated.needsReauth = false
        _ = try codexAuthData(for: updated)
        return updated
    }

    /// Do not undo an external account switch while a token refresh was in flight.
    static func syncCodexRefresh(from old: Account, to updated: Account, url: URL) throws {
        guard let data = try CodexAuthStore(url: url).load(),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["auth_mode"] as? String == "chatgpt",
              let tokens = json["tokens"] as? [String: String],
              tokens["access_token"] == old.accessToken,
              tokens["account_id"] == old.accountId else { return }
        try switchCodex(to: updated, url: url)
    }

    /// Build a fresh identity; never merge token or API-key fields from the
    /// previously signed-in account. Codex requires an id_token to deserialize.
    static func codexAuthData(for account: Account) throws -> Data {
        guard account.provider == .openai, !account.needsReauth,
              !account.accessToken.isEmpty, !account.refreshToken.isEmpty,
              let accountId = account.accountId, !accountId.isEmpty,
              let idToken = account.idToken, !idToken.isEmpty else {
            throw OAuthError.incompleteCodexIdentity
        }
        let claims = JWT.claims(idToken)
        let profile = claims["https://api.openai.com/profile"] as? [String: Any]
        let email = claims["email"] as? String ?? profile?["email"] as? String
        let auth = claims["https://api.openai.com/auth"] as? [String: Any]
        guard email?.lowercased() == account.email.lowercased(),
              (auth?["chatgpt_account_id"] as? String).map({ $0 == accountId }) ?? true else {
            throw OAuthError.incompleteCodexIdentity
        }
        let json: [String: Any] = [
            "auth_mode": "chatgpt", "OPENAI_API_KEY": NSNull(),
            "tokens": ["access_token": account.accessToken, "refresh_token": account.refreshToken,
                       "id_token": idToken, "account_id": accountId],
            "last_refresh": ISO8601DateFormatter().string(from: Date())
        ]
        return try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
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

    private static func restore(_ data: Data?, at url: URL) throws {
        if let data { try atomicWrite(data: data, to: url, permissions: 0o600) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    static func atomicWrite(data: Data, to url: URL, permissions: Int16) throws {
        let dir = url.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".\(url.lastPathComponent).tmp.\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let descriptor = Darwin.open(tempURL.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(permissions))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()

        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL, options: .usingNewMetadataOnly)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: url)
        }

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: url.path
        )
    }
}
