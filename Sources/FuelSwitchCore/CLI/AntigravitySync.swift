import AppKit

/// The standalone Antigravity app keeps its Google sign-in in the Keychain,
/// as the generic password `gemini` / `antigravity` that its language
/// server writes through go-keyring and `/usr/bin/security`. The token is
/// issued for Antigravity's own OAuth client, while FuelSwitch signs Gemini
/// accounts in with the Gemini CLI client, so writing our tokens there would
/// break as soon as Antigravity tried to refresh them.
///
/// A switch therefore swaps whole Antigravity sign-ins: the current one is
/// saved under its email and the target account's saved sign-in, if any, is
/// put back. Antigravity caches the login in memory, so it is quit before
/// the swap and reopened after it, like `CodexDesktopSync` does for Codex.
///
/// Antigravity IDE is left alone: its language servers get the login from
/// the IDE itself, so restarting it would not change its account.
public enum AntigravitySync {
    public enum SyncError: Error { case quitRefused, quitTimedOut, applicationNotFound, signInRequired, accountMismatch }

    public static let bundleIdentifiers = ["com.google.antigravity"]

    /// Where the sign-in lives. Injected in tests instead of the Keychain.
    public struct LoginStore {
        var read: () throws -> Data?
        var write: (Data) throws -> Void
        var delete: () throws -> Void

        public static var keychain: LoginStore { LoginStore(
            read: { try SecurityTool.readGenericPassword(service: "gemini", account: "antigravity") },
            write: { try SecurityTool.writeGenericPassword(service: "gemini", account: "antigravity", data: AntigravitySync.keyringValue(from: $0)) },
            delete: { try SecurityTool.deleteGenericPassword(service: "gemini", account: "antigravity") }
        ) }
    }

    public static var snapshotDirectory: URL {
        AccountStore.defaultDirectory.appendingPathComponent("Antigravity", isDirectory: true)
    }

    /// The account the running standalone app is signed in with, asked from
    /// its language server. Must be called before the app is quit.
    public static func runningSignedInEmail() async -> String? {
        for server in AntigravityLanguageServer.running() where server.isStandaloneApp {
            if let email = await server.signedInEmail() { return email }
        }
        return nil
    }

    /// Best effort for when Antigravity is not running: go-keyring stores the
    /// value as `go-keyring-base64:<base64>`, and the token JSON carries an
    /// ID token with the email.
    static func email(fromStoredLogin data: Data) -> String? {
        var payload = data
        let text = String(decoding: data, as: UTF8.self)
        let prefix = "go-keyring-base64:"
        if text.hasPrefix(prefix), let decoded = Data(base64Encoded: String(text.dropFirst(prefix.count))) {
            payload = decoded
        }
        guard let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else { return nil }
        let idToken = json["id_token"] as? String ?? (json["token"] as? [String: Any])?["id_token"] as? String
        return idToken.flatMap { JWT.claims($0)["email"] as? String }
    }

    public static func hasSavedSignIn(for email: String, snapshotDirectory: URL = snapshotDirectory) -> Bool {
        guard let data = try? Data(contentsOf: snapshotURL(for: email, in: snapshotDirectory)),
              let identity = Self.email(fromStoredLogin: data) else { return false }
        return identity.caseInsensitiveCompare(email) == .orderedSame
    }

    /// Older snapshots are raw JSON; go-keyring requires its base64 envelope.
    static func keyringValue(from data: Data) -> Data {
        let prefix = "go-keyring-base64:"
        if String(decoding: data, as: UTF8.self).hasPrefix(prefix) { return data }
        return Data((prefix + data.base64EncodedString()).utf8)
    }

    /// Saves the current Antigravity sign-in and restores the one saved for
    /// `email`. Without a saved sign-in the Keychain item is removed, so
    /// Antigravity asks to sign in instead of staying on the old account;
    /// that new sign-in is saved on the next switch. Returns whether a saved
    /// sign-in was restored.
    @discardableResult
    public static func swapSignIn(
        to email: String,
        currentEmail: String?,
        store: LoginStore = .keychain,
        snapshotDirectory: URL = snapshotDirectory
    ) throws -> Bool {
        let stored = try store.read()
        let current = stored.flatMap(email(fromStoredLogin:)) ?? currentEmail
        if let current, current.caseInsensitiveCompare(email) == .orderedSame, let stored,
           Self.email(fromStoredLogin: stored) != nil {
            try AtomicFileWriter.write(data: stored, to: snapshotURL(for: current, in: snapshotDirectory), permissions: 0o600)
            return true
        }

        if let stored {
            // An unidentified login is still kept, so it is never lost.
            let name = current ?? "unidentified"
            try AtomicFileWriter.write(data: stored, to: snapshotURL(for: name, in: snapshotDirectory), permissions: 0o600)
        }

        let saved = snapshotURL(for: email, in: snapshotDirectory)
        if FileManager.default.fileExists(atPath: saved.path) {
            let data = try Data(contentsOf: saved)
            if let identity = Self.email(fromStoredLogin: data) {
                guard identity.caseInsensitiveCompare(email) == .orderedSame else { throw SyncError.accountMismatch }
                try store.write(data)
                return true
            }
            // A damaged historical snapshot cannot restore a login. Preserve
            // the snapshot, but open Antigravity signed out for recovery.
        }
        if stored != nil { try store.delete() }
        return false
    }

    static func snapshotURL(for email: String, in directory: URL) -> URL {
        let name = email.lowercased().map { $0.isLetter || $0.isNumber || "@._-".contains($0) ? $0 : "_" }
        return directory.appendingPathComponent(String(name) + ".json")
    }

    /// Quits the running Antigravity app, runs `swap`, then reopens it if it
    /// was running. A failed swap still reopens it.
    @MainActor
    public static func performSwitch(
        enabled: Bool,
        swap: () throws -> Void,
        stop: () async throws -> [URL] = Self.stop,
        open: (URL) async throws -> Void = CodexDesktopSync.open,
        verify: () async throws -> Void = {}
    ) async throws {
        let urls = enabled ? try await stop() : []
        do { try swap() }
        catch {
            for url in urls { try? await open(url) }
            throw error
        }
        for url in urls {
            do { try await open(url) }
            catch { throw SyncError.applicationNotFound }
        }
        if enabled { try await verify() }
    }

    /// Success requires the restarted language server to report the target identity.
    @MainActor
    public static func confirmSignedIn(
        email: String,
        attempts: Int = 40,
        read: () async -> String? = runningSignedInEmail,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(500)) }
    ) async throws {
        for attempt in 0..<attempts {
            if let actual = await read(), actual.caseInsensitiveCompare(email) == .orderedSame { return }
            if attempt + 1 < attempts { try await pause() }
        }
        throw SyncError.accountMismatch
    }

    @MainActor
    static func relaunchURLs(
        runningURLs: [URL?],
        fallback: () throws -> URL
    ) throws -> [URL] {
        var urls: [URL] = []
        for url in runningURLs.compactMap({ $0 }) where !urls.contains(url) { urls.append(url) }
        return urls.isEmpty ? [try fallback()] : urls
    }

    @MainActor
    public static func stop() async throws -> [URL] {
        let applications = bundleIdentifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        // Read the bundle locations before quitting: a terminated
        // NSRunningApplication no longer reports its bundleURL, which left
        // nothing to reopen.
        let urls = try relaunchURLs(runningURLs: applications.map(\.bundleURL)) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifiers[0]) else {
                throw SyncError.applicationNotFound
            }
            return url
        }
        for application in applications {
            guard application.terminate() else { throw SyncError.quitRefused }
        }
        do {
            try await CodexDesktopSync.waitForExit(isRunning: { applications.contains { !$0.isTerminated } })
        } catch {
            throw SyncError.quitTimedOut
        }
        return urls
    }
}
