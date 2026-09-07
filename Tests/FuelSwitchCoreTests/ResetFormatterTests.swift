import Testing
import Foundation
@testable import FuelSwitchCore

private let now = Date(timeIntervalSince1970: 1_788_537_404) // 2026-09-04 15:56 UTC

@Test func noDateGivesADash() {
    #expect(ResetFormatter.string(for: nil, now: now) == "—")
}

@Test func aPastDateGivesNow() {
    #expect(ResetFormatter.string(for: now.addingTimeInterval(-5), now: now) == "now")
}

@Test func underAnHourGivesMinutesOnly() {
    #expect(ResetFormatter.string(for: now.addingTimeInterval(23 * 60), now: now) == "in 23m")
}

@Test func countdownWithSecondsFormatsCorrectly() {
    #expect(ResetFormatter.string(for: now.addingTimeInterval(2 * 3600 + 15 * 60 + 42), now: now, includeSeconds: true) == "in 2h 15m 42s")
    #expect(ResetFormatter.string(for: now.addingTimeInterval(4 * 60 + 8), now: now, includeSeconds: true) == "in 4m 08s")
    #expect(ResetFormatter.string(for: now.addingTimeInterval(25), now: now, includeSeconds: true) == "in 25s")
}

@Test func underADayGivesHoursAndMinutes() {
    #expect(ResetFormatter.string(for: now.addingTimeInterval(3 * 3600 + 3 * 60), now: now) == "in 3h 03m")
}

@Test func overADayGivesADateAndTime() {
    let inSevenDays = now.addingTimeInterval(7 * 86_400)
    let result = ResetFormatter.string(for: inSevenDays, now: now)

    // Derive the expected value with the same formatter configuration as the
    // production code.
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "d MMM HH:mm"
    let expected = formatter.string(from: inSevenDays)

    #expect(result == expected)
}

// F2: 1-59 seconds to a reset used to truncate to "in 0m", which looks like a bug.
@Test func secondsUntilResetNeverRenderAsZeroMinutes() {
    #expect(ResetFormatter.string(for: now.addingTimeInterval(45), now: now) == "in <1m")
    #expect(ResetFormatter.string(for: now.addingTimeInterval(1), now: now) == "in <1m")
}

// F2: the age of cached data has to be distinguishable from freshness — never "now".
@Test func cacheAgeUnderAMinuteReadsAsJustNow() {
    #expect(ResetFormatter.stringSince(now.addingTimeInterval(-30), now: now) == "just now")
}

@Test func cacheAgeInMinutes() {
    #expect(ResetFormatter.stringSince(now.addingTimeInterval(-4 * 60), now: now) == "4m ago")
}

@Test func cacheAgeInHours() {
    #expect(ResetFormatter.stringSince(now.addingTimeInterval(-12 * 3600), now: now) == "12h ago")
}

@Test func cacheAgeInDays() {
    #expect(ResetFormatter.stringSince(now.addingTimeInterval(-3 * 86_400), now: now) == "3d ago")
}

@Test func cacheAgeNeverReadsAsNow() {
    // Twelve hours old is exactly the case from finding F2: the old formatter,
    // built for future dates, returned "now" here.
    #expect(ResetFormatter.stringSince(now.addingTimeInterval(-12 * 3600), now: now) != "now")
}
