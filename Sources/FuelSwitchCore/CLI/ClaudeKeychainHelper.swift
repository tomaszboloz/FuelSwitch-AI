import Foundation
import Security

extension CLISwitcher {
    static let claudeKeychainService = "Claude Code-credentials"

    static func readClaudeKeychainCredentials() throws -> Data? {
        try SecurityTool.readGenericPassword(service: claudeKeychainService)
    }

    static func writeClaudeKeychainCredentials(_ data: Data) throws {
        let account = try SecurityTool.genericPasswordAccount(service: claudeKeychainService) ?? NSUserName()
        try SecurityTool.writeGenericPassword(service: claudeKeychainService, account: account, data: data)
    }

    static func updateClaudeKeychainCredentials(account: Account) throws {
        var existingDict: [String: Any] = [:]
        if let data = try readClaudeKeychainCredentials(),
           let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            existingDict = dict
        }
        existingDict["claudeAiOauth"] = claudeOAuthPayload(
            existing: existingDict["claudeAiOauth"] as? [String: Any] ?? [:],
            account: account
        )
        try writeClaudeKeychainCredentials(try JSONSerialization.data(withJSONObject: existingDict))
    }

    static func claudeOAuthPayload(existing: [String: Any], account: Account) -> [String: Any] {
        var oauth = existing
        oauth["accessToken"] = account.accessToken
        oauth["refreshToken"] = account.refreshToken
        oauth["expiresAt"] = Int64(account.expiresAt.timeIntervalSince1970 * 1000)
        oauth["subscriptionType"] = account.plan ?? "pro"
        oauth["emailAddress"] = account.email
        if let org = account.organizationName { oauth["organizationName"] = org }
        else { oauth.removeValue(forKey: "organizationName") }
        if oauth["scopes"] == nil {
            oauth["scopes"] = ["user:file_upload", "user:inference", "user:mcp_servers", "user:profile", "user:sessions:claude_code"]
        }
        return oauth
    }
}
