import Testing
@testable import FuelSwitchCore

@Suite struct ThresholdWatcherTests {
    private let thresholds = [75, 90, 95]

    @Test func firstCrossingFires() async {
        let watcher = ThresholdWatcher()
        let crossing = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 80, thresholds: thresholds)
        #expect(crossing?.threshold == 75)
        #expect(crossing?.windowLabel == "5h")
    }

    @Test func noRefireWhileStillAboveSameStep() async {
        let watcher = ThresholdWatcher()
        _ = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 80, thresholds: thresholds)
        let second = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 82, thresholds: thresholds)
        #expect(second == nil)
    }

    @Test func firesAgainOnNextHigherStep() async {
        let watcher = ThresholdWatcher()
        _ = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 80, thresholds: thresholds)
        let second = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 91, thresholds: thresholds)
        #expect(second?.threshold == 90)
    }

    @Test func bigJumpReportsOnlyHighestCrossedLevel() async {
        let watcher = ThresholdWatcher()
        let crossing = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 97, thresholds: thresholds)
        #expect(crossing?.threshold == 95)
    }

    @Test func rearmsAfterDroppingBelowLowestThreshold() async {
        let watcher = ThresholdWatcher()
        _ = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 96, thresholds: thresholds)
        let dropped = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 10, thresholds: thresholds)
        #expect(dropped == nil)
        let refired = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 80, thresholds: thresholds)
        #expect(refired?.threshold == 75)
    }

    @Test func sessionAndWeeklyRearmIndependently() async {
        let watcher = ThresholdWatcher()
        let session = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 80, thresholds: thresholds)
        let weekly = await watcher.evaluate(accountId: "a", windowLabel: "week", percent: 80, thresholds: thresholds)
        #expect(session?.threshold == 75)
        #expect(weekly?.threshold == 75)
    }

    @Test func belowLowestThresholdNeverFires() async {
        let watcher = ThresholdWatcher()
        let crossing = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 50, thresholds: thresholds)
        #expect(crossing == nil)
    }

    @Test func forgetClearsArmedStateForAccount() async {
        let watcher = ThresholdWatcher()
        _ = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 96, thresholds: thresholds)
        await watcher.forget(accountId: "a")
        let refired = await watcher.evaluate(accountId: "a", windowLabel: "5h", percent: 96, thresholds: thresholds)
        #expect(refired?.threshold == 95)
    }
}
