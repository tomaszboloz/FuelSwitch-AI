import Foundation
import Testing
@testable import FuelSwitchCore

@Suite struct CodexAccountSwitchTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FUELSWITCH_CODEX_TEST_BINARY"] != nil))
    func installedCodexAcceptsWrittenLoginInAnIsolatedHome() throws {
        let binary = try #require(ProcessInfo.processInfo.environment["FUELSWITCH_CODEX_TEST_BINARY"])
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try CLISwitcher.switchCodex(to: account(), url: dir.appendingPathComponent("auth.json"))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["login", "status"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = dir.path
        environment.removeValue(forKey: "OPENAI_API_KEY")
        environment.removeValue(forKey: "CODEX_API_KEY")
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let message = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(process.terminationStatus == 0)
        #expect(message.localizedCaseInsensitiveContains("ChatGPT"))
    }
    private func account(email: String = "new@example.com", accountId: String = "new-id") throws -> Account {
        let claims: [String: Any] = ["email": email, "https://api.openai.com/auth": ["chatgpt_account_id": accountId]]
        let payload = (try JSONSerialization.data(withJSONObject: claims)).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let jwt = "e30." + payload + ".sig"
        return Account(provider: .openai, email: email, accessToken: "new-access", refreshToken: "new-refresh",
                       expiresAt: .distantFuture, accountId: accountId, idToken: jwt)
    }

    @Test func removesAllPreviousAuthenticationMaterial() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("auth.json")
        try Data(#"{"OPENAI_API_KEY":"old-api-key","agent_identity":"old-agent","tokens":{"account_id":"old-id","id_token":"old-id-token","extra":"old"}}"#.utf8).write(to: url)
        try CLISwitcher.switchCodex(to: account(), url: url)
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let tokens = try #require(json["tokens"] as? [String: String])
        #expect(tokens.count == 4)
        #expect(tokens["account_id"] == "new-id")
        #expect(json["OPENAI_API_KEY"] is NSNull)
        #expect(json["agent_identity"] == nil)
        #expect(CLISwitcher.activeCodexEmail(url: url) == "new@example.com")
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
    }

    @Test func invalidIdentityNeverOverwritesLogin() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("auth.json")
        let original = Data("original-login".utf8)
        try original.write(to: url)
        var incomplete = try account()
        incomplete.idToken = nil
        #expect(throws: OAuthError.incompleteCodexIdentity) { try CLISwitcher.switchCodex(to: incomplete, url: url) }
        var mismatch = try account()
        mismatch.accountId = "other-workspace"
        #expect(throws: OAuthError.incompleteCodexIdentity) { try CLISwitcher.switchCodex(to: mismatch, url: url) }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func honorsCodexHome() {
        #expect(CLISwitcher.codexHome(environment: ["CODEX_HOME": "/tmp/alternate-codex"]).path == "/tmp/alternate-codex")
        #expect(CLISwitcher.codexHome(environment: ["CODEX_HOME": " "]).lastPathComponent == ".codex")
    }

    @Test func adoptsNewerCodexTokensAndDoesNotUndoAnExternalSwitch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("auth.json")
        var original = try account()
        original.expiresAt = .distantPast
        var rotated = original
        rotated.accessToken = "e30." + Data(#"{"exp":2000000000}"#.utf8).base64EncodedString() + ".sig"
        rotated.refreshToken = "rotated-refresh"
        try CLISwitcher.switchCodex(to: rotated, url: url)
        let adopted = try #require(try CLISwitcher.newerCodexCredentials(for: original, url: url))
        #expect(adopted.refreshToken == "rotated-refresh")
        let other = try account(email: "other@example.com", accountId: "other-id")
        try CLISwitcher.switchCodex(to: other, url: url)
        try CLISwitcher.syncCodexRefresh(from: original, to: rotated, url: url)
        #expect(CLISwitcher.activeCodexEmail(url: url) == other.email)
        #expect(try CLISwitcher.newerCodexCredentials(for: original, url: url) == nil)
    }

    @Test func failedClaudeKeychainWriteRestoresMetadataAndCache() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("claude.json")
        let original = Data(#"{"oauthAccount":{"emailAddress":"old@example.com"},"cachedUsageUtilization":{"old":true}}"#.utf8)
        try original.write(to: url)
        let next = Account(provider: .anthropic, email: "new@example.com")
        #expect(throws: CLISwitcher.Error.self) {
            try CLISwitcher.switchClaude(to: next, url: url, keychainUpdater: { _ in throw CLISwitcher.Error.keychain(-1) })
        }
        #expect(try Data(contentsOf: url) == original)
        try CLISwitcher.switchClaude(to: next, url: url, keychainUpdater: { _ in })
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(json["cachedUsageUtilization"] == nil)
    }

    @Test func selectsOnlySupportedTopLevelStorageModes() throws {
        #expect(try CodexAuthStore.mode(config: "") == .file)
        #expect(try CodexAuthStore.mode(config: "cli_auth_credentials_store = 'keyring' # comment\n[other]\ncli_auth_credentials_store='file'") == .keyring)
        #expect(throws: CodexAuthStore.StoreError.self) { try CodexAuthStore.mode(config: "cli_auth_credentials_store='ephemeral'") }
        #expect(throws: CodexAuthStore.StoreError.self) { try CodexAuthStore.mode(config: "cli_auth_credentials_store='keyring'\n[features]\nsecret_auth_storage=true") }
        #expect(try CodexAuthStore.mode(config: "cli_auth_credentials_store='auto'\n[features]\nsecret_auth_storage=false") == .auto)
    }

    @Test func autoModeUsesKeyringInsteadOfStaleFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("cli_auth_credentials_store='auto'".utf8).write(to: dir.appendingPathComponent("config.toml"))
        let url = dir.appendingPathComponent("auth.json")
        try Data("old-file".utf8).write(to: url)
        var keyring: Data? = Data("old-keyring".utf8)
        let store = CodexAuthStore(url: url, readKeychain: { _ in keyring }, writeKeychain: { _, data in keyring = data })
        let data = try CLISwitcher.codexAuthData(for: account())
        try store.save(data)
        #expect(try store.load() == data)
        let failing = CodexAuthStore(url: url, readKeychain: { _ in keyring }, writeKeychain: { _, _ in throw CLISwitcher.Error.keychain(-1) })
        #expect(throws: CLISwitcher.Error.self) { try failing.save(Data("bad".utf8)) }
        #expect(try Data(contentsOf: url) == Data("old-file".utf8))
    }

    @Test @MainActor func desktopWaitDoesNotProceedWhileAppIsRunning() async throws {
        await #expect(throws: CodexDesktopSync.SyncError.quitTimedOut) {
            try await CodexDesktopSync.waitForExit(isRunning: { true }, attempts: 2, pause: {})
        }
        try await CodexDesktopSync.waitForExit(isRunning: { false }, attempts: 1, pause: {})
    }

    @Test @MainActor func desktopSettingControlsLifecycleAndWriteOrder() async throws {
        let url = URL(fileURLWithPath: "/Applications/Codex.app")
        var events: [String] = []
        try await CodexDesktopSync.performSwitch(enabled: false, writeCredentials: { events.append("write") },
            stop: { events.append("stop"); return url }, open: { _ in events.append("open") })
        #expect(events == ["write"])
        events = []
        try await CodexDesktopSync.performSwitch(enabled: true, writeCredentials: { events.append("write") },
            stop: { events.append("stop"); return url }, open: { _ in events.append("open") })
        #expect(events == ["stop", "write", "open"])
    }

    @Test @MainActor func refusedQuitDoesNotChangeLoginAndWriteFailureReopensApp() async throws {
        var events: [String] = []
        await #expect(throws: CodexDesktopSync.SyncError.quitRefused) {
            try await CodexDesktopSync.performSwitch(enabled: true, writeCredentials: { events.append("write") },
                stop: { throw CodexDesktopSync.SyncError.quitRefused }, open: { _ in events.append("open") })
        }
        #expect(events.isEmpty)
        await #expect(throws: CLISwitcher.Error.self) {
            try await CodexDesktopSync.performSwitch(enabled: true,
                writeCredentials: { events.append("write"); throw CLISwitcher.Error.keychain(-1) },
                stop: { events.append("stop"); return URL(fileURLWithPath: "/Applications/Codex.app") },
                open: { _ in events.append("open") })
        }
        #expect(events == ["stop", "write", "open"])
    }

    @Test func desktopSyncIsOptInAndPersists() throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        #expect(!preferences.codexDesktopSyncEnabled)
        preferences.codexDesktopSyncEnabled = true
        #expect(Preferences(defaults: defaults).codexDesktopSyncEnabled)
    }
}
