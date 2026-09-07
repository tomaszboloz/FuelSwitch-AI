import Foundation

public enum ResetFormatter {
    private static let absolute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()

    /// Time until a reset, in a form that reads at a glance. Under a day it
    /// counts down; beyond that it names the date.
    /// If `includeSeconds` is true, displays hours, minutes, and seconds (`in 2h 14m 32s` or `in 14m 32s` or `in 32s`).
    public static func string(for date: Date?, now: Date = Date(), includeSeconds: Bool = false) -> String {
        guard let date else { return "—" }
        let delta = date.timeIntervalSince(now)
        if delta <= 0 { return "now" }

        if includeSeconds && delta < 86_400 {
            let totalSeconds = Int(delta)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60
            if hours > 0 {
                return String(format: "in %dh %02dm %02ds", hours, minutes, seconds)
            } else if minutes > 0 {
                return String(format: "in %dm %02ds", minutes, seconds)
            } else {
                return String(format: "in %ds", seconds)
            }
        }

        // Below a full minute `Int(delta / 60)` truncates to zero, and "in 0m"
        // for a reset 45 seconds away reads as a bug rather than as "any moment".
        if delta < 60 { return "in <1m" }
        if delta < 3600 {
            return "in \(Int(delta / 60))m"
        }
        if delta < 86_400 {
            let hours = Int(delta / 3600)
            let minutes = Int(delta.truncatingRemainder(dividingBy: 3600) / 60)
            return String(format: "in %dh %02dm", hours, minutes)
        }
        return absolute.string(from: date)
    }

    /// Age of cached data. Unlike `string(for:)` this date is always in the
    /// past, which is why it gets its own format instead of sharing code with
    /// the forward-looking formatter: that one returns "now" for any
    /// non-positive difference, so twelve-hour-old data would read as fresh —
    /// and it would err in the direction that looks most reassuring (see F2).
    public static func stringSince(_ date: Date, now: Date = Date()) -> String {
        let delta = max(0, now.timeIntervalSince(date))
        if delta < 60 { return "just now" }
        if delta < 3600 { return "\(Int(delta / 60))m ago" }
        if delta < 86_400 { return "\(Int(delta / 3600))h ago" }
        return "\(Int(delta / 86_400))d ago"
    }
}
