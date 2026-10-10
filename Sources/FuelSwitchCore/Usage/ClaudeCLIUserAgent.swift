import Foundation

enum ClaudeCLIUserAgent {
    /// Keep requests usable on systems where Claude Code is not installed. The
    /// installed CLI version takes precedence, so this value does not go stale
    /// when Anthropic releases a newer CLI.
    static let fallbackVersion = "2.1.285"

    static let current = make(version: detectVersion() ?? fallbackVersion)

    static func make(version: String?) -> String {
        let version = version.flatMap(parseVersion) ?? fallbackVersion
        return "claude-cli/\(version) (external, cli)"
    }

    static func parseVersion(_ output: String) -> String? {
        guard let candidate = output.split(whereSeparator: \.isWhitespace).first,
              candidate.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil
        else { return nil }
        return String(candidate)
    }

    static func executableCandidates(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        var directories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: NSString(string: String($0)).expandingTildeInPath, isDirectory: true) }
        directories.append(homeDirectory.appendingPathComponent(".local/bin", isDirectory: true))
        directories.append(URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true))
        directories.append(URL(fileURLWithPath: "/usr/local/bin", isDirectory: true))

        var seen = Set<String>()
        return directories.compactMap { directory in
            let path = directory.standardizedFileURL.path
            guard seen.insert(path).inserted else { return nil }
            return directory.appendingPathComponent("claude")
        }
    }

    static func detectVersion(
        candidates: [URL] = executableCandidates(),
        isExecutable: (URL) -> Bool = { FileManager.default.isExecutableFile(atPath: $0.path) },
        readOutput: (URL) -> String? = readVersionOutput
    ) -> String? {
        for candidate in candidates where isExecutable(candidate) {
            if let output = readOutput(candidate), let version = parseVersion(output) {
                return version
            }
        }
        return nil
    }

    private static func readVersionOutput(from executable: URL) -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--version"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            let exited = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in exited.signal() }
            try process.run()
            guard exited.wait(timeout: .now() + 2) == .success else {
                process.terminate()
                return nil
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
