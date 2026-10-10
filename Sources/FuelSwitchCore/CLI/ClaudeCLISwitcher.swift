import Foundation
import Security

extension CLISwitcher {
    public static func activeClaudeEmail(url: URL = claudeConfigURL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauthAccount = json["oauthAccount"] as? [String: Any],
              let email = oauthAccount["emailAddress"] as? String else { return nil }
        return email
    }

    public static func cachedClaudeUsage(url: URL = claudeConfigURL) -> AccountUsage? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cached = json["cachedUsageUtilization"] as? [String: Any],
              let util = cached["utilization"] as? [String: Any] else { return nil }

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

        return AccountUsage(session: session, weekly: weekly, scoped: [], fetchedAt: fetchedAt, staleness: .fresh)
    }

    public static func switchClaude(to account: Account, url: URL = claudeConfigURL) throws {
        try switchClaude(to: account, url: url, keychainUpdater: updateClaudeKeychainCredentials)
    }

    static func switchClaude(to account: Account, url: URL, keychainUpdater: (Account) throws -> Void) throws {
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

        var oauthAccount: [String: Any] = ["emailAddress": account.email]
        if let org = account.organizationName { oauthAccount["organizationName"] = org }
        json["oauthAccount"] = oauthAccount
        json.removeValue(forKey: "cachedUsageUtilization")

        let updatedData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data: updatedData, to: url, permissions: 0o600)
        do {
            try keychainUpdater(account)
        } catch {
            try restore(previousData, at: url)
            throw error
        }
    }

    static func newerClaudeCredentials(
        for account: Account,
        keychainReader: () throws -> Data? = readClaudeKeychainCredentials,
        configURL: URL = claudeConfigURL
    ) throws -> Account? {
        guard account.provider == .anthropic,
              let data = try keychainReader(),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let email = oauth["emailAddress"] as? String ?? activeClaudeEmail(url: configURL),
              email.caseInsensitiveCompare(account.email) == .orderedSame,
              let accessToken = oauth["accessToken"] as? String,
              let refreshToken = oauth["refreshToken"] as? String else { return nil }

        let expiryMs: Double? = (oauth["expiresAt"] as? NSNumber)?.doubleValue ?? (oauth["expiresAt"] as? Double)
        guard let expiryMs else { return nil }
        let expiresAt = Date(timeIntervalSince1970: expiryMs / 1000)
        guard !accessToken.isEmpty, !refreshToken.isEmpty,
              expiresAt >= account.expiresAt,
              expiresAt > account.expiresAt || accessToken != account.accessToken || refreshToken != account.refreshToken else {
            return nil
        }

        var updated = account
        updated.accessToken = accessToken
        updated.refreshToken = refreshToken
        updated.expiresAt = expiresAt
        updated.needsReauth = false
        return updated
    }

    static func syncClaudeRefresh(from old: Account, to updated: Account) throws {
        guard old.provider == .anthropic, updated.provider == .anthropic,
              let data = try readClaudeKeychainCredentials(),
              let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let merged = claudeCredentialsAfterRefresh(existing: existing, from: old, to: updated) else { return }
        try writeClaudeKeychainCredentials(try JSONSerialization.data(withJSONObject: merged))
    }

    static func claudeCredentialsAfterRefresh(existing: [String: Any], from old: Account, to updated: Account) -> [String: Any]? {
        guard old.provider == .anthropic, updated.provider == .anthropic, old.id == updated.id,
              let existingOAuth = existing["claudeAiOauth"] as? [String: Any],
              (existingOAuth["emailAddress"] as? String).map({ $0.caseInsensitiveCompare(old.email) == .orderedSame }) ?? true,
              existingOAuth["accessToken"] as? String == old.accessToken,
              existingOAuth["refreshToken"] as? String == old.refreshToken else { return nil }

        var result = existing
        result["claudeAiOauth"] = claudeOAuthPayload(existing: existingOAuth, account: updated)
        return result
    }
}
