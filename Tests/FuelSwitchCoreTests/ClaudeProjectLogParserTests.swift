import Foundation
import Testing
@testable import FuelSwitchCore

struct ClaudeProjectLogParserTests {
    private var fixtureURL: URL {
        Bundle.module.url(forResource: "Fixtures/claude_project_log", withExtension: "jsonl")!
    }

    @Test func parsesOnlyAssistantLinesWithAUsageBlock() {
        let entries = ClaudeProjectLogParser.parseFile(at: fixtureURL)
        #expect(entries.count == 3)
    }

    @Test func extractsModelAndTokenFieldsFromTheUsageBlock() {
        let entries = ClaudeProjectLogParser.parseFile(at: fixtureURL)
        let first = entries[0]
        #expect(first.model == "claude-sonnet-5")
        #expect(first.inputTokens == 10)
        #expect(first.outputTokens == 200)
        #expect(first.cacheCreationTokens == 1000)
        #expect(first.cacheReadTokens == 500)
        #expect(first.totalTokens == 1710)
    }

    @Test func truncatesTheTimestampToTheStartOfItsCalendarDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let entries = ClaudeProjectLogParser.parseFile(at: fixtureURL, calendar: utc)
        let components = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: entries[0].date)
        #expect(components.year == 2026 && components.month == 9 && components.day == 1)
        #expect(components.hour == 0 && components.minute == 0 && components.second == 0)
    }

    @Test func aMalformedOrNonAssistantLineIsSkippedWithoutFailingTheFile() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let entries = ClaudeProjectLogParser.parseFile(at: fixtureURL, calendar: utc)
        #expect(entries.map(\.model) == ["claude-sonnet-5", "claude-sonnet-5", "claude-opus-5"])
    }

    @Test func aMissingProjectsDirectoryYieldsNoEntriesRatherThanFailing() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString)")
        let entries = ClaudeProjectLogParser.parseAllProjects(projectsRoot: missing)
        #expect(entries.isEmpty)
    }

    @Test func parseAllProjectsWalksEveryJsonlFileUnderEveryProjectDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let projectDir = root.appendingPathComponent("some-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = projectDir.appendingPathComponent("session.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: destination)

        let entries = ClaudeProjectLogParser.parseAllProjects(projectsRoot: root)
        #expect(entries.count == 3)
    }
}
