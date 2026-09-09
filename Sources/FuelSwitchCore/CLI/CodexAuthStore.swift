import Foundation
import Security
import CryptoKit

/// Matches Codex's file/auto/direct-keyring credential storage. Never silently
/// writes a file when an explicitly configured backend would ignore it.
struct CodexAuthStore {
    let url: URL
    var readKeychain: (String) throws -> Data? = Self.readKeychain
    var writeKeychain: (String, Data) throws -> Void = Self.writeKeychain

    enum StoreError: Error { case unsupportedConfiguration }
    enum Mode: String { case file, auto, keyring }

    func mode() throws -> Mode {
        let config = url.deletingLastPathComponent().appendingPathComponent("config.toml")
        guard FileManager.default.fileExists(atPath: config.path) else { return .file }
        return try Self.mode(config: String(contentsOf: config, encoding: .utf8))
    }

    static func mode(config: String) throws -> Mode {
        var settings: [String: String] = [:]
        var section = ""
        var encrypted = false
        for line in config.components(separatedBy: .newlines) {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("[") {
                section = String(text.split(separator: "#", maxSplits: 1).first ?? "").trimmingCharacters(in: .whitespaces)
                continue
            }
            let fields = text.split(separator: "=", maxSplits: 1).map(String.init)
            guard fields.count == 2 else { continue }
            let key = fields[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let value = (fields[1].split(separator: "#", maxSplits: 1).first ?? "")
                .trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if section.isEmpty && key == "cli_auth_credentials_store" { settings[key] = value }
            if (section == "[features]" && key == "secret_auth_storage") || (section.isEmpty && key == "features.secret_auth_storage") {
                encrypted = value != "false"
            }
            // Inline feature tables need a full TOML parser; fail closed if
            // the secret-storage flag is present rather than guess its value.
            if section.isEmpty && key == "features" && value.contains("secret_auth_storage") { encrypted = true }
        }
        guard let mode = Mode(rawValue: settings["cli_auth_credentials_store"] ?? "file"),
              mode == .file || !encrypted else {
            throw StoreError.unsupportedConfiguration
        }
        return mode
    }

    var key: String {
        let home = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let hash = SHA256.hash(data: Data(home.utf8)).map { String(format: "%02x", $0) }.joined()
        return "cli|" + hash.prefix(16)
    }

    func load() throws -> Data? {
        let mode = try mode()
        if mode != .file {
            do {
                if let data = try readKeychain(key) { return data }
            } catch { if mode == .keyring { throw error } }
            if mode == .keyring { return nil }
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func save(_ data: Data) throws {
        let mode = try mode()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if mode != .file {
            // Fail closed even in auto mode: a failed write can leave an old
            // keyring entry, which Codex would prefer over a new fallback file.
            try writeKeychain(key, data)
            guard try readKeychain(key) == data else { throw StoreError.unsupportedConfiguration }
            return
        }
        try CLISwitcher.atomicWrite(data: data, to: url, permissions: 0o600)
    }

    private static func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "Codex Auth", kSecAttrAccount as String: key]
    }

    private static func readKeychain(_ key: String) throws -> Data? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CLISwitcher.Error.keychain(status) }
        return item as? Data
    }

    private static func writeKeychain(_ key: String, _ data: Data) throws {
        let query = query(key)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CLISwitcher.Error.keychain(status) }
    }
}
