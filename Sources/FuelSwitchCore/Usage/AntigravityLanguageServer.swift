import Foundation

/// A running Antigravity language server. Each Antigravity window and the
/// standalone Antigravity app start their own server, each signed in with
/// its own account, and each answers Connect RPCs on a few local ports
/// guarded by the CSRF token from its command line.
struct AntigravityLanguageServer {
    let pid: Int
    let command: String
    let csrfToken: String

    /// The standalone app, as opposed to an Antigravity IDE window.
    var isStandaloneApp: Bool { command.contains("/Antigravity.app/") }

    static func running() -> [AntigravityLanguageServer] {
        guard let output = run("/bin/ps", ["-eo", "pid,command"]) else { return [] }
        return output.components(separatedBy: .newlines).compactMap { line in
            guard line.contains("language_server"), line.contains("--csrf_token") else { return nil }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let pid = trimmed.components(separatedBy: .whitespaces).first.flatMap(Int.init) else { return nil }
            let parts = line.components(separatedBy: "--csrf_token")
            let csrfToken = parts[1].trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces).first ?? ""
            guard !csrfToken.isEmpty else { return nil }
            return AntigravityLanguageServer(pid: pid, command: trimmed, csrfToken: csrfToken)
        }
    }

    func ports() -> [Int] {
        guard let output = Self.run("/usr/sbin/lsof", ["-Pan", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]) else { return [] }
        return output.components(separatedBy: .newlines).compactMap { line in
            guard line.contains("LISTEN"), let colon = line.range(of: ":")?.upperBound else { return nil }
            return line[colon...].components(separatedBy: .whitespaces).first.flatMap(Int.init)
        }
    }

    /// The first successful answer from any of the server's ports. Some of
    /// them speak plain HTTP and fail the TLS handshake at once.
    func call(_ method: String) async -> Data? {
        let session = URLSession(configuration: .ephemeral, delegate: InsecureLocalSessionDelegate.shared, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        for port in ports() {
            guard let url = URL(string: "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/\(method)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 1.0
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
            request.httpBody = Data("{}".utf8)
            if let (data, response) = try? await session.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                return data
            }
        }
        return nil
    }

    func signedInEmail() async -> String? {
        guard let status = await call("GetUserStatus") else { return nil }
        return GeminiUsage.languageServerEmail(status)
    }

    private static func run(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

private final class InsecureLocalSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = InsecureLocalSessionDelegate()
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust,
           challenge.protectionSpace.host == "127.0.0.1" || challenge.protectionSpace.host == "localhost" {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
