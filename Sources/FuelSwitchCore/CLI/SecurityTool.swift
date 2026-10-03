import Foundation

/// Generic-password access through `/usr/bin/security`.
///
/// Claude Code and Antigravity (through go-keyring) create and rewrite their
/// Keychain items with this tool, so it is the items' trusted application.
/// Reading them with SecItemCopyMatching from FuelSwitch instead triggers a
/// "wants to use your confidential information" prompt, and every rewrite by
/// the owning app resets the item's access list, so the prompt kept coming
/// back. Going through the same tool avoids it.
enum SecurityTool {
    private static let tool = URL(fileURLWithPath: "/usr/bin/security")
    private static let itemNotFound: Int32 = 44

    static func readGenericPassword(service: String, account: String? = nil) throws -> Data? {
        var arguments = ["find-generic-password", "-s", service]
        if let account { arguments += ["-a", account] }
        let result = try run(arguments + ["-w"])
        if result.status == itemNotFound { return nil }
        guard result.status == 0 else { throw CLISwitcher.Error.keychain(OSStatus(result.status)) }
        let text = String(decoding: result.output, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // `security -w` prints the value as hex when it is not plain ASCII,
        // e.g. an organisation name with diacritics.
        if let decoded = Data(hexString: text) { return decoded }
        return Data(text.utf8)
    }

    enum WriteError: Error { case commandTooLong, verificationFailed }

    static func writeCommand(service: String, account: String, data: Data) throws -> Data {
        let value: String
        if let text = String(data: data, encoding: .utf8),
           text.unicodeScalars.allSatisfy({ (32...126).contains(Int($0.value)) }) {
            // Match go-keyring: its ASCII base64 envelope must not be doubled
            // into hex, which exceeds security's 4096-byte interactive buffer.
            value = "-w \(quoted(text))"
        } else {
            value = "-X " + data.map { String(format: "%02x", $0) }.joined()
        }
        let command = Data("add-generic-password -U -a \(quoted(account)) -s \(quoted(service)) \(value)\n".utf8)
        // Reject before executing; security can partially write an oversized line.
        guard command.count < 4096 else { throw WriteError.commandTooLong }
        return command
    }

    static func writeGenericPassword(service: String, account: String, data: Data) throws {
        // The secret stays on stdin, never in the process arguments.
        let command = try writeCommand(service: service, account: account, data: data)
        let result = try run(["-i"], input: command)
        guard result.status == 0 else { throw CLISwitcher.Error.keychain(OSStatus(result.status)) }
        guard try readGenericPassword(service: service, account: account) == data else {
            throw WriteError.verificationFailed
        }
    }

    static func deleteGenericPassword(service: String, account: String) throws {
        let result = try run(["delete-generic-password", "-s", service, "-a", account])
        guard result.status == 0 || result.status == itemNotFound else {
            throw CLISwitcher.Error.keychain(OSStatus(result.status))
        }
    }

    /// The existing item's account attribute, without reading its secret.
    static func genericPasswordAccount(service: String) throws -> String? {
        let result = try run(["find-generic-password", "-s", service])
        if result.status == itemNotFound { return nil }
        guard result.status == 0 else { throw CLISwitcher.Error.keychain(OSStatus(result.status)) }
        let text = String(decoding: result.output, as: UTF8.self)
        for line in text.split(separator: "\n") where line.contains("\"acct\"<blob>=\"") {
            guard let open = line.range(of: "=\"") else { continue }
            let value = line[open.upperBound...]
            return value.hasSuffix("\"") ? String(value.dropLast()) : String(value)
        }
        return nil
    }

    private static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func run(_ arguments: [String], input: Data? = nil) throws -> (status: Int32, output: Data) {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let stdin = Pipe()
        process.standardInput = input == nil ? FileHandle.nullDevice : stdin
        try process.run()
        if let input {
            stdin.fileHandleForWriting.write(input)
            try? stdin.fileHandleForWriting.close()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, data)
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2), !hexString.isEmpty else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
