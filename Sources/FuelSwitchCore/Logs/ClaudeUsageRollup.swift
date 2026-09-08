import Foundation

/// One calendar day's total token usage, zero-filled — what a heatmap grid
/// needs to render a fixed-width span regardless of gaps in the source logs.
public struct DailyTokenUsage: Sendable, Equatable, Identifiable {
    public let date: Date
    public let totalTokens: Int
    public var id: Date { date }

    public init(date: Date, totalTokens: Int) {
        self.date = date
        self.totalTokens = totalTokens
    }
}

public enum ClaudeUsageRollup {
    /// Sums `totalTokens` per calendar day across all entries. Days with no
    /// entries are simply absent — use `lastDays` for a zero-filled grid.
    public static func dailyTotals(from entries: [ClaudeLogEntry]) -> [DailyTokenUsage] {
        var totals: [Date: Int] = [:]
        for entry in entries {
            totals[entry.date, default: 0] += entry.totalTokens
        }
        return totals.map { DailyTokenUsage(date: $0.key, totalTokens: $0.value) }.sorted { $0.date < $1.date }
    }

    /// The last `days` calendar days ending at `referenceDate` (inclusive),
    /// zero-filled for days with no logged activity.
    public static func lastDays(
        _ days: Int,
        from entries: [ClaudeLogEntry],
        endingAt referenceDate: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [DailyTokenUsage] {
        guard days > 0 else { return [] }
        let totalsByDay = Dictionary(uniqueKeysWithValues: dailyTotals(from: entries).map { ($0.date, $0.totalTokens) })
        let today = calendar.startOfDay(for: referenceDate)

        return (0..<days).reversed().compactMap { offset -> DailyTokenUsage? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTokenUsage(date: day, totalTokens: totalsByDay[day] ?? 0)
        }
    }
}
