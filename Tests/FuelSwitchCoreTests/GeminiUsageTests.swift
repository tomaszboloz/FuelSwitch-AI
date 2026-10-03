import Testing
import Foundation
@testable import FuelSwitchCore

@Test func parsesGeminiUsagePercentages() throws {
    let json = """
    {
        "buckets": [
            { "modelId": "gemini-2.5-flash", "remainingFraction": 1.0, "resetTime": "2026-09-07T18:00:00Z" },
            { "modelId": "gemini-2.5-pro", "remainingFraction": 0.43, "resetTime": "2026-09-14T00:00:00Z" }
        ]
    }
    """
    let data = Data(json.utf8)
    let usage = try GeminiUsage.parse(data, fetchedAt: Date())

    #expect(usage.session.percent == 0)
    #expect(abs(usage.weekly.percent - 57) < 0.000_001)
    #expect(usage.weekly.resetsAt == ISO8601DateFormatter().date(from: "2026-09-14T00:00:00Z"))
    #expect(usage.scoped.count == 2)
}

@Test func parsesGeminiUsageWithMissingQuotaGracefully() throws {
    let data = Data("{}".utf8)
    let usage = try GeminiUsage.parse(data, fetchedAt: Date())

    #expect(usage.session.percent == 0)
    #expect(usage.weekly.percent == 0)
}

@Test func readsTheAccountALocalLanguageServerIsSignedInWith() {
    let status = Data(#"{"userStatus": {"name": "A", "email": "a@example.com", "planStatus": {}}}"#.utf8)
    #expect(GeminiUsage.languageServerEmail(status) == "a@example.com")
    #expect(GeminiUsage.languageServerEmail(Data(#"{"userStatus": {}}"#.utf8)) == nil)
    #expect(GeminiUsage.languageServerEmail(Data("not json".utf8)) == nil)
}

@Test func parsesLocalAntigravityQuotaSummary() throws {
    let json = """
    {"response": {"groups": [{"displayName": "Gemini Models", "buckets": [
        {"bucketId": "gemini-weekly", "displayName": "Weekly", "window": "WEEKLY", "remainingFraction": 0.66, "resetTime": "2026-10-09T12:00:00Z"},
        {"bucketId": "gemini-5h", "displayName": "Five Hour", "window": "FIVE_HOUR", "remainingFraction": 0.99, "resetTime": "2026-10-03T23:00:00Z"}
    ]}]}}
    """
    let usage = try GeminiUsage.parseLocalQuota(Data(json.utf8))
    #expect(abs(usage.weekly.percent - 34) < 0.000_001)
    #expect(abs(usage.session.percent - 1) < 0.000_001)
}
