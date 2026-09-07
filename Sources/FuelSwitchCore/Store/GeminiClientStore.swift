import Foundation

/// The user's own Gemini OAuth client, entered once through the "Connect
/// Gemini" setup sheet. Stored in a plain file with 0600 permissions rather
/// than the keychain, for the same reason as `AccountStore`: the app is
/// signed ad hoc, so its signature — and therefore any keychain access list
/// tied to it — changes on every rebuild.
public struct GeminiClientCredentials: Codable, Sendable, Equatable {
    public let clientID: String
    public let clientSecret: String

    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
    }
}

public struct GeminiClientStore: Sendable {
    public let fileURL: URL
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("gemini_client.json")
    }

    public static var `default`: GeminiClientStore {
        GeminiClientStore(directory: AccountStore.defaultDirectory)
    }

    public func load() -> GeminiClientCredentials? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(GeminiClientCredentials.self, from: data)
    }

    /// Writes the file only when saving succeeds — a caller must not treat a
    /// silently-dropped write as a saved connection.
    public func save(_ credentials: GeminiClientCredentials) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(credentials)

        let temporary = directory.appendingPathComponent(".gemini_client.\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: temporary.path
            )
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: fileURL)
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: fileURL.path
            )
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
