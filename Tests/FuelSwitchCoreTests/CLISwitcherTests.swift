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
}
