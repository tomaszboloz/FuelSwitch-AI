import Foundation

extension CLISwitcher {
    public static func activeCodexEmail(url: URL = codexAuthURL, knownAccounts: [Account] = []) -> String? {
        guard let data = try? CodexAuthStore(url: url).load(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any] else { return nil }

        if let idToken = tokens["id_token"] as? String {
            let claims = JWT.claims(idToken)
            if let profile = claims["https://api.openai.com/profile"] as? [String: Any],
               let email = profile["email"] as? String { return email }
            if let email = claims["email"] as? String { return email }
        }
        if let accessToken = tokens["access_token"] as? String {
            let claims = JWT.claims(accessToken)
            if let profile = claims["https://api.openai.com/profile"] as? [String: Any],
               let email = profile["email"] as? String { return email }
            if let email = claims["email"] as? String { return email }
        }
        if let accountId = tokens["account_id"] as? String,
           let matched = knownAccounts.first(where: { $0.provider == .openai && $0.accountId == accountId }) {
            return matched.email
        }
        return nil
    }

    public static func switchCodex(to account: Account, url: URL = codexAuthURL) throws {
        try CodexAuthStore(url: url).save(Self.codexAuthData(for: account))
    }

    public static func validateCodexSwitch(to account: Account, url: URL = codexAuthURL) throws {
        _ = try codexAuthData(for: account)
        _ = try CodexAuthStore(url: url).mode()
    }

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

    static func syncCodexRefresh(from old: Account, to updated: Account, url: URL) throws {
        guard let data = try CodexAuthStore(url: url).load(),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["auth_mode"] as? String == "chatgpt",
              let tokens = json["tokens"] as? [String: String],
              tokens["access_token"] == old.accessToken,
              tokens["account_id"] == old.accountId else { return }
        try switchCodex(to: updated, url: url)
    }

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
}
