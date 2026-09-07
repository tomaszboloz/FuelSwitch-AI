import Testing
import Foundation
@testable import FuelSwitchCore

private func fixture(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json")
    return try Data(contentsOf: #require(url))
}

@Test func parsesTheFiveHourAndWeeklyWindows() throws {
    let usage = try AnthropicUsage.parse(fixture("anthropic_usage"), fetchedAt: Date())
    #expect(usage.session.percent == 54)
    #expect(usage.weekly.percent == 10)
    #expect(usage.staleness == .fresh)
}

@Test func parsesASixDigitFractionOfASecond() throws {
    let usage = try AnthropicUsage.parse(fixture("anthropic_usage"), fetchedAt: Date())
    let expected = Date(timeIntervalSince1970: 1_788_550_200) // 2026-09-04 19:30 UTC
    let difference = try #require(usage.session.resetsAt).timeIntervalSince(expected)
    #expect(abs(difference) < 1)
}

@Test func extractsPerModelLimitsAsScoped() throws {
    let usage = try AnthropicUsage.parse(fixture("anthropic_usage"), fetchedAt: Date())
    #expect(usage.scoped.count == 1)
    #expect(usage.scoped.first?.label == "Fable")
}

@Test func anEmptyResponseGivesEmptyWindows() throws {
    let usage = try AnthropicUsage.parse(Data("{}".utf8), fetchedAt: Date())
    #expect(usage.session.percent == 0)
    #expect(usage.scoped.isEmpty)
}

@Test func parsesADateWithNoFractionOfASecond() throws {
    let jsonWithoutFraction = """
    {
      "five_hour": {
        "utilization": 54.0,
        "resets_at": "2026-09-04T19:30:00+00:00"
      },
      "seven_day": {
        "utilization": 10.0,
        "resets_at": "2026-09-11T08:00:00+00:00"
      }
    }
    """
    let usage = try AnthropicUsage.parse(Data(jsonWithoutFraction.utf8), fetchedAt: Date())
    let expected = Date(timeIntervalSince1970: 1_788_550_200) // 2026-09-04 19:30 UTC
    let difference = try #require(usage.session.resetsAt).timeIntervalSince(expected)
    #expect(abs(difference) < 1)
}
