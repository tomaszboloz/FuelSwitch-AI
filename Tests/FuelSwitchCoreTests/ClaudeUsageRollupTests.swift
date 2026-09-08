import Foundation
import Testing
@testable import FuelSwitchCore

struct ClaudeUsageRollupTests {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func sumsTokensPerCalendarDayAcrossMultipleEntriesOnTheSameDay() {
        let entries = [
            ClaudeLogEntry(date: day(2026, 9, 1), model: "a", inputTokens: 10, outputTokens: 20, cacheCreationTokens: 0, cacheReadTokens: 0),
            ClaudeLogEntry(date: day(2026, 9, 1), model: "b", inputTokens: 5, outputTokens: 5, cacheCreationTokens: 0, cacheReadTokens: 0),
            ClaudeLogEntry(date: day(2026, 9, 2), model: "a", inputTokens: 100, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
        ]
        let totals = ClaudeUsageRollup.dailyTotals(from: entries)
        #expect(totals.count == 2)
        #expect(totals[0].date == day(2026, 9, 1))
        #expect(totals[0].totalTokens == 40)
        #expect(totals[1].totalTokens == 100)
    }

    @Test func dailyTotalsIsEmptyForNoEntries() {
        #expect(ClaudeUsageRollup.dailyTotals(from: []).isEmpty)
    }

    @Test func lastDaysZeroFillsDaysWithNoLoggedActivity() {
        let entries = [
            ClaudeLogEntry(date: day(2026, 9, 1), model: "a", inputTokens: 100, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
        ]
        let result = ClaudeUsageRollup.lastDays(3, from: entries, endingAt: day(2026, 9, 3), calendar: utc)
        #expect(result.count == 3)
        #expect(result.map(\.date) == [day(2026, 9, 1), day(2026, 9, 2), day(2026, 9, 3)])
        #expect(result.map(\.totalTokens) == [100, 0, 0])
    }

    @Test func lastDaysIncludesTheReferenceDateItself() {
        let entries = [
            ClaudeLogEntry(date: day(2026, 9, 5), model: "a", inputTokens: 50, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
        ]
        let result = ClaudeUsageRollup.lastDays(1, from: entries, endingAt: day(2026, 9, 5), calendar: utc)
        #expect(result.count == 1)
        #expect(result[0].totalTokens == 50)
    }

    @Test func lastDaysWithZeroReturnsAnEmptyArray() {
        #expect(ClaudeUsageRollup.lastDays(0, from: [], endingAt: day(2026, 9, 5)).isEmpty)
    }
}
