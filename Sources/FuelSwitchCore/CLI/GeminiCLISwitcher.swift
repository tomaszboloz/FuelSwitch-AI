import Foundation

extension CLISwitcher {
    public static func activeGeminiEmail(url: URL = geminiActiveAccountURL, knownAccounts: [Account] = []) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["active"] as? String
    }

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
}
