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
