import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct CLISwitcherTests {

    @Test func readsActiveClaudeEmailFromFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let claudeFile = tempDir.appendingPathComponent(".claude.json")
        let sampleClaude: [String: Any] = [
            "numStartups": 5,
            "oauthAccount": [
                "emailAddress": "test@example.com",
                "organizationName": "Test Org"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: sampleClaude)
        try data.write(to: claudeFile)

        let email = CLISwitcher.activeClaudeEmail(url: claudeFile)
        #expect(email == "test@example.com")
    }

    @Test func readsActiveCodexEmailFromJWTInAuthFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let codexFile = tempDir.appendingPathComponent("auth.json")
        
        // Construct a dummy JWT with email
        let header = "{\"alg\":\"none\"}".data(using: .utf8)!.base64EncodedString()
        let payload = "{\"email\":\"codex-user@openai.com\"}".data(using: .utf8)!.base64EncodedString()
        let dummyJWT = "\(header).\(payload)."

        let sampleAuth: [String: Any] = [
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": dummyJWT,
                "access_token": "acc-123",
                "refresh_token": "ref-123",
                "account_id": "acc-id-456"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: sampleAuth)
        try data.write(to: codexFile)

        let email = CLISwitcher.activeCodexEmail(url: codexFile)
        #expect(email == "codex-user@openai.com")
    }

    @Test func switchesCodexAccountAndPreservesTokens() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let codexFile = tempDir.appendingPathComponent("auth.json")

        let header = "{\"alg\":\"none\"}".data(using: .utf8)!.base64EncodedString()
        let payload = "{\"email\":\"new-codex@openai.com\"}".data(using: .utf8)!.base64EncodedString()
        let dummyJWT = "\(header).\(payload)."

        let account = Account(
            provider: .openai,
            email: "new-codex@openai.com",
            accessToken: "new-acc-tok",
            refreshToken: "new-ref-tok",
            accountId: "new-acc-id",
            idToken: dummyJWT
        )

        try CLISwitcher.switchCodex(to: account, url: codexFile)

        let readEmail = CLISwitcher.activeCodexEmail(url: codexFile)
        #expect(readEmail == "new-codex@openai.com")

        let data = try Data(contentsOf: codexFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let tokens = json?["tokens"] as? [String: Any]
        #expect(tokens?["access_token"] as? String == "new-acc-tok")
        #expect(tokens?["refresh_token"] as? String == "new-ref-tok")
        #expect(tokens?["account_id"] as? String == "new-acc-id")
    }

    @Test func copiesClaudeAccountDataIntoOAuthCredentials() {
        let expiry = Date(timeIntervalSince1970: 1_700_000_000)
        let account = Account(
            provider: .anthropic,
            email: "claude@example.com",
            plan: "max",
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: expiry,
            organizationName: "Example Org"
        )

        let oauth = CLISwitcher.claudeOAuthPayload(
            existing: ["scopes": ["existing:scope"], "stale": "preserved"],
            account: account
        )

        #expect(oauth["accessToken"] as? String == "access-token")
        #expect(oauth["refreshToken"] as? String == "refresh-token")
        #expect(oauth["expiresAt"] as? Int64 == 1_700_000_000_000)
        #expect(oauth["subscriptionType"] as? String == "max")
        #expect(oauth["emailAddress"] as? String == "claude@example.com")
        #expect(oauth["organizationName"] as? String == "Example Org")
        #expect(oauth["scopes"] as? [String] == ["existing:scope"])
        #expect(oauth["stale"] as? String == "preserved")
    }

    @Test func adoptsNewerClaudeCodeCredentialsFromKeychain() throws {
        let oldExpiry = Date(timeIntervalSince1970: 1_700_000_000)
        let account = Account(
            provider: .anthropic,
            email: "claude@example.com",
            accessToken: "old-access",
            refreshToken: "old-refresh",
            expiresAt: oldExpiry
        )
        let payload: [String: Any] = [
            "claudeAiOauth": [
                "emailAddress": account.email,
                "accessToken": "rotated-access",
                "refreshToken": "rotated-refresh",
                "expiresAt": 1_700_003_600_000
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let candidate = try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { data })
        let updated = try #require(candidate)
        #expect(updated.accessToken == "rotated-access")
        #expect(updated.refreshToken == "rotated-refresh")
        #expect(updated.expiresAt == Date(timeIntervalSince1970: 1_700_003_600))
        #expect(updated.needsReauth == false)
    }

    @Test func ignoresClaudeCredentialsForAnotherAccountOrOlderSession() throws {
        let account = Account(
            provider: .anthropic,
            email: "claude@example.com",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 1_700_003_600)
        )
        let other: [String: Any] = [
            "claudeAiOauth": [
                "emailAddress": "other@example.com",
                "accessToken": "other-access",
                "refreshToken": "other-refresh",
                "expiresAt": 1_900_000_000_000
            ]
        ]
        let older: [String: Any] = [
            "claudeAiOauth": [
                "emailAddress": account.email,
                "accessToken": account.accessToken,
                "refreshToken": account.refreshToken,
                "expiresAt": 1_700_003_600_000
            ]
        ]

        let otherData = try JSONSerialization.data(withJSONObject: other)
        let olderData = try JSONSerialization.data(withJSONObject: older)
        #expect(try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { otherData }) == nil)
        #expect(try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { olderData }) == nil)
    }

    @Test func adoptsClaudeRotationWithoutEmailInKeychain() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = directory.appendingPathComponent(".claude.json")
        let account = Account(provider: .anthropic, email: "claude@example.com",
                              accessToken: "old-access", refreshToken: "old-refresh",
                              expiresAt: Date(timeIntervalSince1970: 1_700_000_000), needsReauth: true)
        let data = try JSONSerialization.data(withJSONObject: ["claudeAiOauth": [
            "accessToken": "rotated-access", "refreshToken": "rotated-refresh",
            "expiresAt": 1_700_003_600_000
        ]])
        // No account identity means the credential cannot be adopted.
        #expect(try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { data }, configURL: config) == nil)
        try JSONSerialization.data(withJSONObject: ["oauthAccount": ["emailAddress": account.email]]).write(to: config)
        let candidate = try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { data }, configURL: config)
        let updated = try #require(candidate)
        #expect(updated.accessToken == "rotated-access")
        #expect(updated.refreshToken == "rotated-refresh")
        #expect(!updated.needsReauth)
        // The active CLI account must match the monitored account.
        try JSONSerialization.data(withJSONObject: ["oauthAccount": ["emailAddress": "other@example.com"]]).write(to: config)
        #expect(try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { data }, configURL: config) == nil)
    }

    @Test func doesNotAdoptAnOlderClaudeTokenWithDifferentValues() throws {
        let account = Account(provider: .anthropic, email: "claude@example.com",
                              accessToken: "new-access", refreshToken: "new-refresh",
                              expiresAt: Date(timeIntervalSince1970: 1_700_003_600))
        let data = try JSONSerialization.data(withJSONObject: ["claudeAiOauth": [
            "emailAddress": account.email, "accessToken": "old-access",
            "refreshToken": "old-refresh", "expiresAt": 1_700_000_000_000
        ]])
        #expect(try CLISwitcher.newerClaudeCredentials(for: account, keychainReader: { data }) == nil)
    }

    @Test func syncsClaudeRotationWithoutEmailOnlyWhenTokensMatch() throws {
        let old = Account(provider: .anthropic, email: "claude@example.com",
                          accessToken: "old-access", refreshToken: "old-refresh")
        var updated = old
        updated.accessToken = "new-access"
        updated.refreshToken = "new-refresh"
        let existing: [String: Any] = ["claudeAiOauth": [
            "accessToken": old.accessToken, "refreshToken": old.refreshToken,
            "scopes": ["user:profile"]
        ]]
        let merged = try #require(CLISwitcher.claudeCredentialsAfterRefresh(existing: existing, from: old, to: updated))
        let oauth = try #require(merged["claudeAiOauth"] as? [String: Any])
        #expect(oauth["accessToken"] as? String == updated.accessToken)
        #expect(oauth["scopes"] as? [String] == ["user:profile"])
        let switched: [String: Any] = ["claudeAiOauth": [
            "accessToken": "another-access", "refreshToken": "another-refresh"
        ]]
        #expect(CLISwitcher.claudeCredentialsAfterRefresh(existing: switched, from: old, to: updated) == nil)
    }

    @Test func switchesClaudeAccountWhenItsConfigDoesNotExist() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let claudeFile = tempDir.appendingPathComponent(".claude.json")
        let account = Account(
            provider: .anthropic,
            email: "claude@example.com",
            organizationName: "Example Org"
        )

        try CLISwitcher.switchClaude(to: account, url: claudeFile, keychainUpdater: { _ in })

        #expect(CLISwitcher.activeClaudeEmail(url: claudeFile) == account.email)

        let data = try Data(contentsOf: claudeFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let oauthAccount = json?["oauthAccount"] as? [String: Any]
        #expect(oauthAccount?["organizationName"] as? String == "Example Org")
    }

    @Test func readsActiveGeminiEmailFromGoogleAccountsFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let accountsFile = tempDir.appendingPathComponent("google_accounts.json")
        let sample: [String: Any] = ["active": "gemini-user@gmail.com", "old": ["previous@gmail.com"]]
        try JSONSerialization.data(withJSONObject: sample).write(to: accountsFile)

        let email = CLISwitcher.activeGeminiEmail(url: accountsFile)
        #expect(email == "gemini-user@gmail.com")
    }

    @Test func switchesGeminiAccountAndWritesBothRealFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let accountsFile = tempDir.appendingPathComponent("google_accounts.json")
        let credsFile = tempDir.appendingPathComponent("oauth_creds.json")

        let existing: [String: Any] = ["active": "old-user@gmail.com", "old": []]
        try JSONSerialization.data(withJSONObject: existing).write(to: accountsFile)

        let expiry = Date(timeIntervalSince1970: 1_700_000_000)
        let account = Account(
            provider: .gemini,
            email: "new-gemini@gmail.com",
            accessToken: "gem-access-tok",
            refreshToken: "gem-refresh-tok",
            expiresAt: expiry,
            idToken: "gem-id-tok"
        )

        try CLISwitcher.switchGemini(to: account, activeAccountURL: accountsFile, oauthCredsURL: credsFile)

        #expect(CLISwitcher.activeGeminiEmail(url: accountsFile) == "new-gemini@gmail.com")

        let accountsData = try Data(contentsOf: accountsFile)
        let accountsJSON = try JSONSerialization.jsonObject(with: accountsData) as? [String: Any]
        #expect(accountsJSON?["old"] as? [String] == ["old-user@gmail.com"])

        let credsData = try Data(contentsOf: credsFile)
        let credsJSON = try JSONSerialization.jsonObject(with: credsData) as? [String: Any]
        #expect(credsJSON?["access_token"] as? String == "gem-access-tok")
        #expect(credsJSON?["refresh_token"] as? String == "gem-refresh-tok")
        #expect(credsJSON?["id_token"] as? String == "gem-id-tok")
        #expect(credsJSON?["token_type"] as? String == "Bearer")
        #expect(credsJSON?["expiry_date"] as? Int64 == 1_700_000_000_000)
    }
}
