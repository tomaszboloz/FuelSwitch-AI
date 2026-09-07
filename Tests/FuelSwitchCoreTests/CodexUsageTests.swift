import Testing
import Foundation
@testable import FuelSwitchCore

private func codexFixture() throws -> Data {
    let url = Bundle.module.url(forResource: "Fixtures/codex_usage", withExtension: "json")
    return try Data(contentsOf: #require(url))
}

@Test func parsesBothCodexWindows() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.usage.session.percent == 100)
    #expect(result.usage.weekly.percent == 16)
    #expect(result.usage.scoped.isEmpty)
}

@Test func convertsTheEpochToADate() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.usage.session.resetsAt == Date(timeIntervalSince1970: 1_788_548_409))
}

@Test func extractsTheEmailAndPlan() throws {
    let result = try CodexUsage.parse(codexFixture(), fetchedAt: Date())
    #expect(result.email == "account@example.com")
    #expect(result.plan == "team")
}

@Test func aMissingRateLimitSectionGivesEmptyWindows() throws {
    let result = try CodexUsage.parse(Data(#"{"email":"a@b.pl"}"#.utf8), fetchedAt: Date())
    #expect(result.usage.session.percent == 0)
    #expect(result.usage.weekly.resetsAt == nil)
}
