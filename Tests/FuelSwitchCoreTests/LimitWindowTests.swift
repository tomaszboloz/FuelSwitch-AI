import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct LimitWindowTests {
    @Test func remainingPercentAndLowFuelCalculation() {
        let normal = LimitWindow(percent: 50, resetsAt: nil, label: "5h")
        #expect(normal.remainingPercent == 50)
        #expect(normal.isLowFuel == false)

        let low = LimitWindow(percent: 85, resetsAt: nil, label: "5h")
        #expect(low.remainingPercent == 15)
        #expect(low.isLowFuel == true)

        let empty = LimitWindow.empty
        #expect(empty.percent == 0)
        #expect(empty.remainingPercent == 100)
        #expect(empty.isLowFuel == false)

        let overconsumed = LimitWindow(percent: 120, resetsAt: nil, label: "5h")
        #expect(overconsumed.remainingPercent == 0)
        #expect(overconsumed.isLowFuel == true)
    }

    @Test func accountUsageWorstAndRemainingPercent() {
        let usage = AccountUsage(
            session: LimitWindow(percent: 30, resetsAt: nil, label: "5h"),
            weekly: LimitWindow(percent: 70, resetsAt: nil, label: "7d"),
            scoped: [LimitWindow(percent: 90, resetsAt: nil, label: "Scoped")],
            fetchedAt: Date(),
            staleness: .fresh
        )
        #expect(usage.worstPercent == 90)
        #expect(usage.remainingPercent == 10)
        #expect(usage.isLowFuel == true)

        let safeUsage = AccountUsage(
            session: LimitWindow(percent: 10, resetsAt: nil, label: "5h"),
            weekly: LimitWindow(percent: 20, resetsAt: nil, label: "7d"),
            scoped: [],
            fetchedAt: Date(),
            staleness: .fresh
        )
        #expect(safeUsage.worstPercent == 20)
        #expect(safeUsage.remainingPercent == 80)
        #expect(safeUsage.isLowFuel == false)
    }

    @Test func stalenessEquality() {
        let now = Date()
        #expect(Staleness.fresh == Staleness.fresh)
        #expect(Staleness.cached(since: now) == Staleness.cached(since: now))
        #expect(Staleness.error("err") == Staleness.error("err"))
        #expect(Staleness.fresh != Staleness.error("err"))
    }
}
