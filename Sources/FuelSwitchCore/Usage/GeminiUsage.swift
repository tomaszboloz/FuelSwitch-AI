import Foundation

/// Gemini CLI exposes quota per model through the Code Assist API. Its values
/// are fractions remaining, whereas the rest of FuelSwitch stores percentages
/// used. Keeping that conversion here makes every UI surface agree.
public enum GeminiUsage {
    private struct Response: Decodable {
        struct Bucket: Decodable {
            let modelId: String?
            let remainingFraction: Double?
            let resetTime: String?
        }

        let buckets: [Bucket]?
    }

    private static func resetDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    public static func parse(_ data: Data, fetchedAt: Date) throws -> AccountUsage {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let windows = (response.buckets ?? []).compactMap { bucket -> LimitWindow? in
            guard let remaining = bucket.remainingFraction else { return nil }
            let used = (1 - min(1, max(0, remaining))) * 100
            return LimitWindow(
                percent: used,
                resetsAt: resetDate(bucket.resetTime),
                label: bucket.modelId ?? "Gemini"
            )
        }

        // Categorize by duration until reset: short-term (5-hour) vs long-term (weekly)
        let shortTermWindows = windows.filter { w in
            guard let resetsAt = w.resetsAt else { return false }
            return resetsAt.timeIntervalSince(fetchedAt) <= 24 * 3600
        }
        let weeklyWindows = windows.filter { w in
            guard let resetsAt = w.resetsAt else { return false }
            return resetsAt.timeIntervalSince(fetchedAt) > 24 * 3600
        }

        let sessionWindow: LimitWindow
        if let bestShort = shortTermWindows.max(by: { $0.percent < $1.percent }) {
            sessionWindow = LimitWindow(percent: bestShort.percent, resetsAt: bestShort.resetsAt, label: "5 hours")
        } else {
            sessionWindow = LimitWindow(percent: 0, resetsAt: nil, label: "5 hours")
        }

        let weeklyWindow: LimitWindow
        if let bestWeekly = weeklyWindows.max(by: { $0.percent < $1.percent }) {
            weeklyWindow = LimitWindow(percent: bestWeekly.percent, resetsAt: bestWeekly.resetsAt, label: "Week")
        } else if let strictest = windows.max(by: { $0.percent < $1.percent }) {
            weeklyWindow = LimitWindow(percent: strictest.percent, resetsAt: strictest.resetsAt, label: "Week")
        } else {
            weeklyWindow = LimitWindow(percent: 0, resetsAt: nil, label: "Week")
        }

        return AccountUsage(
            session: sessionWindow,
            weekly: weeklyWindow,
            scoped: windows,
            fetchedAt: fetchedAt,
            staleness: .fresh
        )
    }

    private struct LocalQuotaResponse: Decodable {
        struct ResponseObj: Decodable {
            struct Group: Decodable {
                let displayName: String?
                let buckets: [Bucket]?
            }
            struct Bucket: Decodable {
                let bucketId: String?
                let displayName: String?
                let window: String?
                let remainingFraction: Double?
                let resetTime: String?
            }
            let groups: [Group]?
        }
        let response: ResponseObj?
    }

    public static func parseLocalQuota(_ data: Data, fetchedAt: Date = Date()) throws -> AccountUsage {
        let decoded = try JSONDecoder().decode(LocalQuotaResponse.self, from: data)
        guard let groups = decoded.response?.groups else {
            throw UsageError.unavailableQuota
        }

        var bucket5h: LocalQuotaResponse.ResponseObj.Bucket?
        var bucketWeekly: LocalQuotaResponse.ResponseObj.Bucket?
        var allScoped: [LimitWindow] = []

        for group in groups {
            for bucket in group.buckets ?? [] {
                if let fraction = bucket.remainingFraction {
                    let used = (1.0 - max(0, min(1.0, fraction))) * 100.0
                    allScoped.append(LimitWindow(
                        percent: used,
                        resetsAt: resetDate(bucket.resetTime),
                        label: bucket.displayName ?? bucket.bucketId ?? "Gemini"
                    ))
                }
                if bucket.bucketId == "gemini-5h" {
                    bucket5h = bucket
                } else if bucket.bucketId == "gemini-weekly" {
                    bucketWeekly = bucket
                }
            }
        }

        guard let b5 = bucket5h, let bw = bucketWeekly,
              let frac5 = b5.remainingFraction, let fracW = bw.remainingFraction else {
            throw UsageError.unavailableQuota
        }

        let sessionPercent = (1.0 - max(0, min(1.0, frac5))) * 100.0
        let weeklyPercent = (1.0 - max(0, min(1.0, fracW))) * 100.0

        let sessionWindow = LimitWindow(
            percent: sessionPercent,
            resetsAt: resetDate(b5.resetTime),
            label: "5 hours"
        )
        let weeklyWindow = LimitWindow(
            percent: weeklyPercent,
            resetsAt: resetDate(bw.resetTime),
            label: "Week"
        )

        return AccountUsage(
            session: sessionWindow,
            weekly: weeklyWindow,
            scoped: allScoped,
            fetchedAt: fetchedAt,
            staleness: .fresh
        )
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

public struct GeminiUsageClient: UsageProvider {
    private static let loadCodeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private static let retrieveUserQuotaURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(account: Account) async throws -> AccountUsage {
        if let localUsage = await fetchFromLocalLanguageServer() {
            return localUsage
        }

        let project = try await companionProject(accessToken: account.accessToken)

        var request = URLRequest(url: Self.retrieveUserQuotaURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.12.2", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["project": project])

        let (data, response) = try await session.data(for: request)
        try checkStatus(response, body: data)
        return try GeminiUsage.parse(data, fetchedAt: Date())
    }

    private func fetchFromLocalLanguageServer() async -> AccountUsage? {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-eo", "pid,command"]
        let pipe = Pipe()
        ps.standardOutput = pipe
        do {
            try ps.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: .newlines) {
            guard line.contains("language_server"), line.contains("--csrf_token") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let pidStr = trimmed.components(separatedBy: .whitespaces).first, let pid = Int(pidStr) else { continue }

            let lineParts = line.components(separatedBy: "--csrf_token")
            guard lineParts.count > 1 else { continue }
            let csrfToken = lineParts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).first ?? ""
            guard !csrfToken.isEmpty else { continue }

            let lsof = Process()
            lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            lsof.arguments = ["-Pan", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
            let lsofPipe = Pipe()
            lsof.standardOutput = lsofPipe
            do {
                try lsof.run()
            } catch {
                continue
            }
            let lsofData = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            lsof.waitUntilExit()
            guard let lsofOut = String(data: lsofData, encoding: .utf8) else { continue }

            for lline in lsofOut.components(separatedBy: .newlines) {
                guard lline.contains("LISTEN"), let colonIdx = lline.range(of: ":")?.upperBound else { continue }
                let portStr = lline[colonIdx...].components(separatedBy: .whitespaces).first ?? ""
                guard let port = Int(portStr), port > 0 else { continue }

                let localSession = URLSession(
                    configuration: .ephemeral,
                    delegate: InsecureLocalSessionDelegate.shared,
                    delegateQueue: nil
                )
                guard let url = URL(string: "https://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary") else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 1.0
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                req.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
                req.httpBody = Data("{}".utf8)

                do {
                    let (responseData, response) = try await localSession.data(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        if let usage = try? GeminiUsage.parseLocalQuota(responseData, fetchedAt: Date()) {
                            return usage
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    private func companionProject(accessToken: String) async throws -> String {
        var request = URLRequest(url: Self.loadCodeAssistURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.12.2", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "metadata": [
                "ideType": "ANTIGRAVITY",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI",
            ],
        ])

        let (data, response) = try await session.data(for: request)
        try checkStatus(response, body: data)

        struct Bootstrap: Decodable { let cloudaicompanionProject: String? }
        guard let project = try JSONDecoder().decode(Bootstrap.self, from: data).cloudaicompanionProject,
              !project.isEmpty
        else {
            throw UsageError.unavailableQuota
        }
        return project
    }
}
