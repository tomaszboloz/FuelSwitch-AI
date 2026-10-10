import Foundation
import Darwin

extension CLISwitcher {
    static func restore(_ data: Data?, at url: URL) throws {
        if let data { try atomicWrite(data: data, to: url, permissions: 0o600) }
        else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    static func atomicWrite(data: Data, to url: URL, permissions: Int16) throws {
        let dir = url.deletingLastPathComponent()
        let tempURL = dir.appendingPathComponent(".\(url.lastPathComponent).tmp.\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let descriptor = Darwin.open(tempURL.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(permissions))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        try handle.synchronize()
        try handle.close()

        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL, options: .usingNewMetadataOnly)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: url)
        }

        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: url.path
        )
    }
}
