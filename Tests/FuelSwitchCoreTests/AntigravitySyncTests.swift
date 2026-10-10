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

    private final class FakeKeychain {
        var value: Data?
        init(_ value: Data?) { self.value = value }
        var store: AntigravitySync.LoginStore {
            AntigravitySync.LoginStore(read: { self.value }, write: { self.value = $0 }, delete: { self.value = nil })
        }
    }

    @Test func readsEmailFromGoKeyringValue() throws {
        let encoded = "go-keyring-base64:" + (try signIn("a@example.com", refresh: "ra")).base64EncodedString()
        #expect(AntigravitySync.email(fromStoredLogin: Data(encoded.utf8)) == "a@example.com")
        #expect(AntigravitySync.email(fromStoredLogin: Data("opaque".utf8)) == nil)
    }

    @Test func wrapsLegacySnapshotForGoKeyringWithoutDoubleEncoding() throws {
        let raw = try signIn("a@example.com", refresh: "ra")
        let encoded = AntigravitySync.keyringValue(from: raw)
        #expect(String(decoding: encoded, as: UTF8.self).hasPrefix("go-keyring-base64:"))
        #expect(AntigravitySync.email(fromStoredLogin: encoded) == "a@example.com")
        #expect(AntigravitySync.keyringValue(from: encoded) == encoded)
    }

    @Test func swapSavesCurrentSignInAndRestoresTarget() throws {
        let snapshots = directory()
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let first = try signIn("a@example.com", refresh: "ra")
        let keychain = FakeKeychain(first)

        // No saved sign-in for B yet: A is kept aside and Antigravity is
        // left signed out, so it asks for B instead of staying on A.
        #expect(try !AntigravitySync.swapSignIn(to: "b@example.com", currentEmail: "a@example.com",
                                                store: keychain.store, snapshotDirectory: snapshots))
        #expect(keychain.value == nil)

        // The user signs in to B inside Antigravity, then switches back to A.
        let second = try signIn("b@example.com", refresh: "rb")
        keychain.value = second
        #expect(try AntigravitySync.swapSignIn(to: "A@example.com", currentEmail: "b@example.com",
                                               store: keychain.store, snapshotDirectory: snapshots))
        #expect(keychain.value == first)

        #expect(try AntigravitySync.swapSignIn(to: "b@example.com", currentEmail: "a@example.com",
                                               store: keychain.store, snapshotDirectory: snapshots))
        #expect(keychain.value == second)
    }

    @Test func swapToTheSignedInAccountChangesNothing() throws {
        let snapshots = directory()
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let login = try signIn("a@example.com", refresh: "ra")
        let keychain = FakeKeychain(login)
        #expect(try AntigravitySync.swapSignIn(to: "a@example.com", currentEmail: "A@example.com",
                                               store: keychain.store, snapshotDirectory: snapshots))
        #expect(keychain.value == login)
        #expect(FileManager.default.fileExists(atPath: snapshots.path))
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

    @Test @MainActor func missingBundleURLUsesInstalledApplicationBeforeQuit() throws {
        let installed = URL(fileURLWithPath: "/Applications/Antigravity.app")
        #expect(try AntigravitySync.relaunchURLs(runningURLs: [nil], fallback: { installed }) == [installed])
        #expect(try AntigravitySync.relaunchURLs(runningURLs: [installed, installed], fallback: { throw AntigravitySync.SyncError.applicationNotFound }) == [installed])
    }

    @Test @MainActor func verificationRunsAfterReopeningAndRejectsWrongAccount() async throws {
        var events: [String] = []
        await #expect(throws: AntigravitySync.SyncError.self) {
            try await AntigravitySync.performSwitch(enabled: true,
                swap: { events.append("swap") }, stop: { events.append("stop"); return [URL(fileURLWithPath: "/Applications/Antigravity.app")] },
                open: { _ in events.append("open") }, verify: {
                    events.append("verify")
                    try await AntigravitySync.confirmSignedIn(email: "b@example.com", attempts: 2,
                        read: { "a@example.com" }, pause: {})
                })
            events.append("success")
        }
        #expect(events == ["stop", "swap", "open", "verify"])
    }

    @Test @MainActor func waitsForTheTargetAccountToFinishStarting() async throws {
        var calls = 0
        try await AntigravitySync.confirmSignedIn(email: "b@example.com", attempts: 3, read: {
            calls += 1
            return calls == 3 ? "B@example.com" : nil
        }, pause: {})
        #expect(calls == 3)
    }

    @Test func rejectsSnapshotForAnotherAccountWithoutChangingCredentials() throws {
        let snapshots = directory()
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let first = try signIn("a@example.com", refresh: "ra")
        let keychain = FakeKeychain(first)
        try AtomicFileWriter.write(data: first,
            to: AntigravitySync.snapshotURL(for: "b@example.com", in: snapshots), permissions: 0o600)
        #expect(throws: AntigravitySync.SyncError.self) {
            try AntigravitySync.swapSignIn(to: "b@example.com", currentEmail: "a@example.com",
                store: keychain.store, snapshotDirectory: snapshots)
        }
        #expect(keychain.value == first)
        #expect(!AntigravitySync.hasSavedSignIn(for: "b@example.com", snapshotDirectory: snapshots))
    }

    @Test func damagedSnapshotOpensSignInAndKeepsCurrentSessionBackedUp() throws {
        let snapshots = directory()
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let login = try signIn("a@example.com", refresh: "ra")
        let keychain = FakeKeychain(login)
        try AtomicFileWriter.write(data: Data("invalid".utf8),
            to: AntigravitySync.snapshotURL(for: "b@example.com", in: snapshots), permissions: 0o600)
        #expect(try !AntigravitySync.swapSignIn(to: "b@example.com", currentEmail: "a@example.com",
            store: keychain.store, snapshotDirectory: snapshots))
        #expect(keychain.value == nil)
        #expect(AntigravitySync.hasSavedSignIn(for: "a@example.com", snapshotDirectory: snapshots))
        #expect(!AntigravitySync.hasSavedSignIn(for: "b@example.com", snapshotDirectory: snapshots))
    }

    @Test func signedOutStubNeverOverwritesSavedSignIn() throws {
        let snapshots = directory()
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let saved = try signIn("b@example.com", refresh: "rb")
        try AtomicFileWriter.write(data: saved,
            to: AntigravitySync.snapshotURL(for: "b@example.com", in: snapshots), permissions: 0o600)
        let keychain = FakeKeychain(Data(#"{"token":{}}"#.utf8))
        _ = try AntigravitySync.swapSignIn(to: "a@example.com", currentEmail: "b@example.com",
            store: keychain.store, snapshotDirectory: snapshots)
        #expect(AntigravitySync.hasSavedSignIn(for: "b@example.com", snapshotDirectory: snapshots))
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
