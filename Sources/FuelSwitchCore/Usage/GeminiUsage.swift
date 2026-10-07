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
            let seconds = resetsAt.timeIntervalSince(fetchedAt)
            return seconds >= 0 && seconds <= 24 * 3600
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

    /// The account a local Antigravity language server is signed in with,
    /// from its `GetUserStatus` answer.
    public static func languageServerEmail(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["userStatus"] as? [String: Any],
              let email = status["email"] as? String, !email.isEmpty
        else { return nil }
        return email
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

public struct GeminiUsageClient: UsageProvider {
    private static let loadCodeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(account: Account) async throws -> AccountUsage {
        // Saved Antigravity credentials let inactive accounts refresh without
        // switching the app. Gemini CLI tokens cannot read these quota windows.
        if let access = try? await AntigravityQuotaSession.shared.accessToken(email: account.email, session: session),
           let usage = try? await fetchAntigravityQuota(accessToken: access, email: account.email) {
            return usage
        }
        // Every Antigravity window runs its own language server, signed in
        // with its own account. Only a server signed in with this account
        // may answer for it; anything else shows another account's quota.
        if let localUsage = await fetchFromLocalLanguageServer(email: account.email) {
            return localUsage
        }

        // Gemini CLI's per-model daily quota is a different allowance. It
        // cannot fill missing Antigravity 5-hour and weekly windows.
        throw UsageError.unavailableQuota
    }

    private func fetchFromLocalLanguageServer(email: String) async -> AccountUsage? {
        for server in AntigravityLanguageServer.running() where server.isStandaloneApp {
            guard let signedIn = await server.signedInEmail(),
                  signedIn.caseInsensitiveCompare(email) == .orderedSame else { continue }
            if let quota = await server.call("RetrieveUserQuotaSummary"),
               let usage = try? GeminiUsage.parseLocalQuota(quota, fetchedAt: Date()),
               let after = await server.signedInEmail(),
               after.caseInsensitiveCompare(email) == .orderedSame {
                return usage
            }
        }
        return nil
    }

    private func fetchAntigravityQuota(accessToken: String, email: String) async throws -> AccountUsage {
        var identityRequest = URLRequest(url: FuelSwitchConstants.geminiUserInfoURL)
        identityRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        identityRequest.timeoutInterval = 15
        let (identity, identityResponse) = try await session.data(for: identityRequest)
        try checkStatus(identityResponse, body: identity)
        guard let profile = try JSONSerialization.jsonObject(with: identity) as? [String: Any],
              (profile["email"] as? String)?.caseInsensitiveCompare(email) == .orderedSame
        else { throw UsageError.unavailableQuota }

        let project = try await companionProject(accessToken: accessToken)
        let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/2.19.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["project": project])
        let (quota, response) = try await session.data(for: request)
        try checkStatus(response, body: quota)
        // The remote endpoint returns the summary directly; Connect wraps it.
        let summary = try JSONSerialization.jsonObject(with: quota)
        let wrapped = try JSONSerialization.data(withJSONObject: ["response": summary])
        return try GeminiUsage.parseLocalQuota(wrapped, fetchedAt: Date())
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
