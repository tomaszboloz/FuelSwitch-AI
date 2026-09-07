import Testing
import Foundation
@testable import FuelSwitchCore

@Test func worstPercentTakesTheHighestValue() {
    let usage = AccountUsage(
        session: LimitWindow(percent: 54, resetsAt: nil, label: "5h"),
        weekly: LimitWindow(percent: 10, resetsAt: nil, label: "7d"),
        scoped: [LimitWindow(percent: 91, resetsAt: nil, label: "Fable")],
        fetchedAt: Date(timeIntervalSince1970: 0),
        staleness: .fresh
    )
    #expect(usage.worstPercent == 91)
}

@Test func anAccountHasAStableIdentifierFromProviderAndEmail() {
    let first = Account(provider: .anthropic, email: "a@b.pl")
    let second = Account(provider: .anthropic, email: "a@b.pl")
    #expect(first.id == second.id)
}
