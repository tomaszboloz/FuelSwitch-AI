import Testing
import Foundation
@testable import FuelSwitchCore

private func account(email: String, needsReauth: Bool = false) -> Account {
    Account(
        provider: .anthropic, email: email,
        accessToken: "tok", refreshToken: "ref", expiresAt: .distantFuture,
        needsReauth: needsReauth
    )
}

private func usage(percent: Double, staleness: Staleness = .fresh) -> AccountUsage {
    AccountUsage(
        session: LimitWindow(percent: percent, resetsAt: nil, label: "5h"),
        weekly: .empty, scoped: [], fetchedAt: Date(), staleness: staleness
    )
}

@Suite struct AutoSwitchDeciderTests {
    @Test func noDecisionWhenActiveIsNotExhausted() {
        let active = account(email: "active@a.com")
        let backup = account(email: "backup@a.com")
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, backup],
            usage: [active.id: usage(percent: 50), backup.id: usage(percent: 0)],
            activeEmail: active.email
        )
        #expect(decision == nil)
    }

    @Test func picksBestOfSeveralCandidates() {
        let active = account(email: "active@a.com")
        let weak = account(email: "weak@a.com")
        let strong = account(email: "strong@a.com")
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, weak, strong],
            usage: [
                active.id: usage(percent: 100),
                weak.id: usage(percent: 60),
                strong.id: usage(percent: 10),
            ],
            activeEmail: active.email
        )
        #expect(decision?.to.email == "strong@a.com")
        #expect(decision?.from.email == "active@a.com")
    }

    @Test func nilWhenAllCandidatesBelowMinimum() {
        let active = account(email: "active@a.com")
        let backup = account(email: "backup@a.com")
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, backup],
            usage: [active.id: usage(percent: 100), backup.id: usage(percent: 90)],
            activeEmail: active.email
        )
        #expect(decision == nil)
    }

    @Test func excludesNeedsReauthCandidates() {
        let active = account(email: "active@a.com")
        let broken = account(email: "broken@a.com", needsReauth: true)
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, broken],
            usage: [active.id: usage(percent: 100), broken.id: usage(percent: 0)],
            activeEmail: active.email
        )
        #expect(decision == nil)
    }

    @Test func excludesErrorStalenessCandidates() {
        let active = account(email: "active@a.com")
        let errored = account(email: "errored@a.com")
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, errored],
            usage: [active.id: usage(percent: 100), errored.id: usage(percent: 0, staleness: .error("down"))],
            activeEmail: active.email
        )
        #expect(decision == nil)
    }

    @Test func ignoresOtherProviderAccounts() {
        let active = account(email: "active@a.com")
        let other = Account(provider: .openai, email: "other@a.com", accessToken: "t", refreshToken: "r", expiresAt: .distantFuture)
        let decision = AutoSwitchDecider.decide(
            provider: .anthropic,
            accounts: [active, other],
            usage: [active.id: usage(percent: 100), other.id: usage(percent: 0)],
            activeEmail: active.email
        )
        #expect(decision == nil)
    }
}
