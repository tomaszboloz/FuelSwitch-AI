import Foundation

/// Write-to-temp-then-replace, shared by everything that must never leave a
/// file readable in a half-written state: credentials, generated caches,
/// config patches. `AccountStore` and `CLISwitcher` each grew their own copy
/// of this before it was pulled out here — new call sites should use this one.
enum AtomicFileWriter {
    static func write(data: Data, to url: URL, permissions: Int16) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).tmp.\(UUID().uuidString)")

        do {
            try data.write(to: temporary, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: permissions)],
                ofItemAtPath: temporary.path
            )

            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }

            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: permissions)],
                ofItemAtPath: url.path
            )
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }
}
