import Foundation
import Testing
@testable import FuelSwitchCore

@Suite struct PaceEstimatorTests {
    private let duration: TimeInterval = 5 * 3600
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func window(percent: Double, elapsedFraction: Double?) -> LimitWindow {
        guard let elapsedFraction else {
            return LimitWindow(percent: percent, resetsAt: nil, label: "5h")
        }
        let remaining = duration * (1 - elapsedFraction)
        return LimitWindow(percent: percent, resetsAt: now.addingTimeInterval(remaining), label: "5h")
    }

    @Test func burningFastWhenUsedFarAheadOfElapsed() {
        let estimate = PaceEstimator.estimate(window: window(percent: 60, elapsedFraction: 0.4), windowDuration: duration, now: now)
        #expect(estimate?.tier == .burningFast)
    }

    @Test func aheadWhenUsedFarBehindElapsed() {
        let estimate = PaceEstimator.estimate(window: window(percent: 20, elapsedFraction: 0.5), windowDuration: duration, now: now)
        #expect(estimate?.tier == .ahead)
    }

    @Test func onPaceWhenWithinMargin() {
        let estimate = PaceEstimator.estimate(window: window(percent: 42, elapsedFraction: 0.4), windowDuration: duration, now: now)
        #expect(estimate?.tier == .onPace)
    }

    @Test func exactlyAtMarginStaysOnPace() {
        let estimate = PaceEstimator.estimate(window: window(percent: 55, elapsedFraction: 0.4), windowDuration: duration, now: now)
        #expect(estimate?.tier == .onPace)
    }

    @Test func justOverMarginBecomesBurningFast() {
        let estimate = PaceEstimator.estimate(window: window(percent: 55.1, elapsedFraction: 0.4), windowDuration: duration, now: now)
        #expect(estimate?.tier == .burningFast)
    }

    @Test func nilWhenResetsAtIsNil() {
        let estimate = PaceEstimator.estimate(window: window(percent: 50, elapsedFraction: nil), windowDuration: duration, now: now)
        #expect(estimate == nil)
    }

    @Test func nilWhenResetsAtHasAlreadyPassed() {
        let past = LimitWindow(percent: 50, resetsAt: now.addingTimeInterval(-10), label: "5h")
        #expect(PaceEstimator.estimate(window: past, windowDuration: duration, now: now) == nil)
    }

    @Test func nilWhenPercentIsZero() {
        let estimate = PaceEstimator.estimate(window: window(percent: 0, elapsedFraction: 0.4), windowDuration: duration, now: now)
        #expect(estimate == nil)
    }

    @Test func nilWhenWindowDurationIsZero() {
        let estimate = PaceEstimator.estimate(window: window(percent: 50, elapsedFraction: 0.4), windowDuration: 0, now: now)
        #expect(estimate == nil)
    }
}
