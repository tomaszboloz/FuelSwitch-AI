import Foundation

/// Swaps whole Antigravity sign-ins in Keychain between accounts.
public enum AntigravitySync {
    public enum SyncError: Error { case quitRefused, quitTimedOut, applicationNotFound, signInRequired, accountMismatch }

    public static let bundleIdentifiers = ["com.google.antigravity"]

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

    public static func runningSignedInEmail() async -> String? {
        for server in AntigravityLanguageServer.running() where server.isStandaloneApp {
            if let email = await server.signedInEmail() { return email }
        }
        return nil
    }

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

    static func keyringValue(from data: Data) -> Data {
        let prefix = "go-keyring-base64:"
        if String(decoding: data, as: UTF8.self).hasPrefix(prefix) { return data }
        return Data((prefix + data.base64EncodedString()).utf8)
    }

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

        // Only a sign-in that names its account is worth keeping. A signed-out
        // stub has no identity and must never overwrite the saved sign-in of
        // the account that was active before it.
        if let stored, let identity = Self.email(fromStoredLogin: stored) {
            try AtomicFileWriter.write(data: stored, to: snapshotURL(for: identity, in: snapshotDirectory), permissions: 0o600)
        }

        let saved = snapshotURL(for: email, in: snapshotDirectory)
        if FileManager.default.fileExists(atPath: saved.path) {
            let data = try Data(contentsOf: saved)
            if let identity = Self.email(fromStoredLogin: data) {
                guard identity.caseInsensitiveCompare(email) == .orderedSame else { throw SyncError.accountMismatch }
                try store.write(data)
                return true
            }
        }
        if stored != nil { try store.delete() }
        return false
    }

    static func snapshotURL(for email: String, in directory: URL) -> URL {
        let name = email.lowercased().map { $0.isLetter || $0.isNumber || "@._-".contains($0) ? $0 : "_" }
        return directory.appendingPathComponent(String(name) + ".json")
    }
}
