import Foundation
import Testing
@testable import FuelSwitchCore

@Suite struct AntigravitySyncTests {
    private func idToken(email: String) -> String {
        let payload = try! JSONSerialization.data(withJSONObject: ["email": email])
        let body = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "e30.\(body).sig"
    }

    private func signIn(_ email: String, refresh: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "token": ["access_token": "a-\(refresh)", "refresh_token": refresh],
            "auth_method": "oauth",
            "id_token": idToken(email: email)
        ])
    }

    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func readsSignedInEmailFromIdToken() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let token = dir.appendingPathComponent("token")
        #expect(AntigravitySync.signedInEmail(tokenURL: token) == nil)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try signIn("a@example.com", refresh: "ra").write(to: token)
        #expect(AntigravitySync.signedInEmail(tokenURL: token) == "a@example.com")
    }

    @Test func swapSavesCurrentSignInAndRestoresTarget() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let token = dir.appendingPathComponent("token")
        let snapshots = dir.appendingPathComponent("snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let first = try signIn("a@example.com", refresh: "ra")
        try first.write(to: token)

        // No saved sign-in for B yet: A is kept aside and Antigravity is
        // left signed out, so it asks for B instead of staying on A.
        #expect(try !AntigravitySync.swapSignIn(to: "b@example.com", tokenURL: token, snapshotDirectory: snapshots))
        #expect(!FileManager.default.fileExists(atPath: token.path))

        // The user signs in to B inside Antigravity, then switches back to A.
        let second = try signIn("b@example.com", refresh: "rb")
        try second.write(to: token)
        #expect(try AntigravitySync.swapSignIn(to: "A@example.com", tokenURL: token, snapshotDirectory: snapshots))
        #expect(try Data(contentsOf: token) == first)

        #expect(try AntigravitySync.swapSignIn(to: "b@example.com", tokenURL: token, snapshotDirectory: snapshots))
        #expect(try Data(contentsOf: token) == second)
    }

    @Test @MainActor func restartsOnlyRunningAppsAroundTheSwap() async throws {
        let url = URL(fileURLWithPath: "/Applications/Antigravity.app")
        var events: [String] = []
        try await AntigravitySync.performSwitch(enabled: false, swap: { events.append("swap") },
            stop: { events.append("stop"); return [url] }, open: { _ in events.append("open") })
        #expect(events == ["swap"])
        events = []
        try await AntigravitySync.performSwitch(enabled: true, swap: { events.append("swap") },
            stop: { events.append("stop"); return [url] }, open: { _ in events.append("open") })
        #expect(events == ["stop", "swap", "open"])
        events = []
        try await AntigravitySync.performSwitch(enabled: true, swap: { events.append("swap") },
            stop: { events.append("stop"); return [] }, open: { _ in events.append("open") })
        #expect(events == ["stop", "swap"])
    }

    @Test @MainActor func failedSwapReopensApp() async throws {
        var events: [String] = []
        await #expect(throws: CLISwitcher.Error.self) {
            try await AntigravitySync.performSwitch(enabled: true,
                swap: { events.append("swap"); throw CLISwitcher.Error.invalidClaudeConfig },
                stop: { events.append("stop"); return [URL(fileURLWithPath: "/Applications/Antigravity.app")] },
                open: { _ in events.append("open") })
        }
        #expect(events == ["stop", "swap", "open"])
    }

    @Test func syncIsOnByDefaultAndPersists() throws {
        let suite = "antigravity-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        #expect(preferences.antigravitySyncEnabled)
        preferences.antigravitySyncEnabled = false
        #expect(!Preferences(defaults: defaults).antigravitySyncEnabled)
    }
}
