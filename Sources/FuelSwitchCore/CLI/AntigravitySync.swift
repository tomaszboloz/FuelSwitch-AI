import AppKit

/// Antigravity (the agent manager and the IDE) keeps its Google sign-in in
/// `~/.gemini/jetski-standalone-oauth-token`, read by its language server.
/// That token is issued for Antigravity's own OAuth client, while FuelSwitch
/// signs Gemini accounts in with the Gemini CLI client, so writing our tokens
/// there would break as soon as Antigravity tried to refresh them.
///
/// A switch therefore swaps whole Antigravity sign-ins: the current one is
/// saved under its email and the target account's saved sign-in, if any, is
/// put back. Antigravity caches the login in memory, so it is quit before
/// the swap and reopened after it, like `CodexDesktopSync` does for Codex.
public enum AntigravitySync {
    public enum SyncError: Error { case quitRefused, quitTimedOut, applicationNotFound }

    public static let bundleIdentifiers = ["com.google.antigravity", "com.google.antigravity-ide"]

    public static var tokenURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
            .appendingPathComponent("jetski-standalone-oauth-token")
    }

    public static var snapshotDirectory: URL {
        AccountStore.defaultDirectory.appendingPathComponent("Antigravity", isDirectory: true)
    }

    /// The account Antigravity is signed in with, from the ID token it saved.
    public static func signedInEmail(tokenURL: URL = tokenURL) -> String? {
        guard let data = try? Data(contentsOf: tokenURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let email = JWT.claims(idToken)["email"] as? String,
              !email.isEmpty
        else { return nil }
        return email
    }

    /// Saves the current Antigravity sign-in and restores the one saved for
    /// `email`. Without a saved sign-in the token file is removed, so
    /// Antigravity asks to sign in instead of staying on the old account;
    /// that new sign-in is saved on the next switch. Returns whether a saved
    /// sign-in was restored.
    @discardableResult
    public static func swapSignIn(
        to email: String,
        tokenURL: URL = tokenURL,
        snapshotDirectory: URL = snapshotDirectory
    ) throws -> Bool {
        let manager = FileManager.default
        if let current = signedInEmail(tokenURL: tokenURL) {
            if current.caseInsensitiveCompare(email) == .orderedSame { return true }
            try AtomicFileWriter.write(
                data: try Data(contentsOf: tokenURL),
                to: snapshotURL(for: current, in: snapshotDirectory),
                permissions: 0o600
            )
        }

        let saved = snapshotURL(for: email, in: snapshotDirectory)
        if manager.fileExists(atPath: saved.path) {
            try AtomicFileWriter.write(data: try Data(contentsOf: saved), to: tokenURL, permissions: 0o600)
            return true
        }
        if manager.fileExists(atPath: tokenURL.path) {
            try manager.removeItem(at: tokenURL)
        }
        return false
    }

    static func snapshotURL(for email: String, in directory: URL) -> URL {
        let name = email.lowercased().map { $0.isLetter || $0.isNumber || "@._-".contains($0) ? $0 : "_" }
        return directory.appendingPathComponent(String(name) + ".json")
    }

    /// Quits the running Antigravity apps, runs `swap`, then reopens only the
    /// apps that were running. A failed swap still reopens them.
    @MainActor
    public static func performSwitch(
        enabled: Bool,
        swap: () throws -> Void,
        stop: () async throws -> [URL] = Self.stop,
        open: (URL) async throws -> Void = CodexDesktopSync.open
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
    }

    @MainActor
    public static func stop() async throws -> [URL] {
        let applications = bundleIdentifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        for application in applications {
            guard application.terminate() else { throw SyncError.quitRefused }
        }
        do {
            try await CodexDesktopSync.waitForExit(isRunning: { applications.contains { !$0.isTerminated } })
        } catch {
            throw SyncError.quitTimedOut
        }
        var urls: [URL] = []
        for url in applications.compactMap(\.bundleURL) where !urls.contains(url) { urls.append(url) }
        return urls
    }
}
