import Testing
@testable import FuelSwitchCore

@Suite struct AdaptiveRefreshPolicyTests {
    @Test func recentActivityQuartersTheInterval() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: 60)
        #expect(interval == 150)
    }

    @Test func moderatelyRecentActivityHalvesTheInterval() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: 10 * 60)
        #expect(interval == 300)
    }

    @Test func staleActivityLeavesTheIntervalUnchanged() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: 60 * 60)
        #expect(interval == 600)
    }

    @Test func nilActivityFallsBackToTheBaseInterval() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: nil)
        #expect(interval == 600)
    }

    @Test func theResultNeverDropsBelowThePollerMinimum() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 120, sinceLastCliActivity: 0)
        #expect(interval == Poller.minimumInterval)
    }

    @Test func boundaryAtFiveMinutesUsesTheHalvedTier() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: 5 * 60)
        #expect(interval == 300)
    }

    @Test func boundaryAtThirtyMinutesUsesTheUnchangedTier() {
        let interval = AdaptiveRefreshPolicy.effectiveInterval(baseInterval: 600, sinceLastCliActivity: 30 * 60)
        #expect(interval == 600)
    }
}
