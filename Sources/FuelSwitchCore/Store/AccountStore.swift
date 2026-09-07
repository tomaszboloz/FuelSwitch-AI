import Foundation

/// Clean Architecture repository contract for persistent account management.
public protocol AccountRepositoryProtocol: Sendable {
    func load() throws -> [Account]
    func save(_ accounts: [Account]) throws
    func upsert(_ account: Account) throws
    func remove(id: String) throws
}

/// Accounts live in a plain file with 0600 permissions rather than in the
/// keychain, because the app is signed ad hoc — the signature changes on every
/// rebuild and would invalidate the access list of a keychain entry.
public struct AccountStore: AccountRepositoryProtocol, Sendable {
    public let fileURL: URL
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("accounts.json")
    }

    public static var `default`: AccountStore {
        AccountStore(directory: Self.defaultDirectory)
    }

    public static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FuelSwitch")
    }

    /// The legacy directories of previous versions — source of automatic migration.
    public static var legacyDirectories: [URL] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacyNames: [String] = [
            String(data: Data(base64Encoded: "SGVhZHJvb20=") ?? Data(), encoding: .utf8) ?? "",
            "Limity"
        ]
        return legacyNames.filter { !$0.isEmpty }.map { appSupport.appendingPathComponent($0) }
    }

    public static var legacyDirectory: URL {
        legacyDirectories[0]
    }

    public func load() throws -> [Account] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode([Account].self, from: data)
    }

    public func save(_ accounts: [Account]) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(accounts)

        // Atomic write: an interruption halfway through must not leave a file
        // from which no account can be read any more.
        //
        // `replaceItemAt` requires the destination to exist already, so we check
        // whether accounts.json is in place and only then choose between
        // replaceItemAt and moveItem. Permissions of 0600 are set on the
        // temporary file BEFORE the move (so tokens never sit, even briefly,
        // with the default 0644) and again on the destination afterwards,
        // because replaceItemAt does not carry the temporary file's attributes
        // across.
        let temporary = directory.appendingPathComponent(".accounts.\(UUID().uuidString).tmp")
        // If anything below throws, the temporary file — which holds tokens —
        // must not be left on disk, so it is removed before the error is
        // rethrown. The `try?` on cleanup is deliberate: a failure to clean up
        // must not mask the original error.
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

    public func upsert(_ account: Account) throws {
        var accounts = try load()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        try save(accounts)
    }

    public func remove(id: String) throws {
        try save(try load().filter { $0.id != id })
    }
}
