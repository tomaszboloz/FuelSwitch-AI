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

        let shortTermWindows = windows.filter { w in
            guard let resetsAt = w.resetsAt else { return false }
            let seconds = resetsAt.timeIntervalSince(fetchedAt)
            return seconds >= 0 && seconds <= 24 * 3600
        }
        let weeklyWindows = windows.filter { w in
            guard let resetsAt = w.resetsAt else { return false }
            return resetsAt.timeIntervalSince(fetchedAt) > 24 * 3600
        }

        let sessionWindow = shortTermWindows.max(by: { $0.percent < $1.percent }).map {
            LimitWindow(percent: $0.percent, resetsAt: $0.resetsAt, label: "5 hours")
        } ?? LimitWindow(percent: 0, resetsAt: nil, label: "5 hours")

        let weeklyWindow = weeklyWindows.max(by: { $0.percent < $1.percent }).map {
            LimitWindow(percent: $0.percent, resetsAt: $0.resetsAt, label: "Week")
        } ?? windows.max(by: { $0.percent < $1.percent }).map {
            LimitWindow(percent: $0.percent, resetsAt: $0.resetsAt, label: "Week")
        } ?? LimitWindow(percent: 0, resetsAt: nil, label: "Week")

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
