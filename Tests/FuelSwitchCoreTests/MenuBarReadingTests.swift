import Testing
import Foundation
@testable import FuelSwitchCore

private func account(_ provider: Provider, _ email: String) -> Account {
    Account(provider: provider, email: email)
}

private func usage(session: Double, weekly: Double = 0, scoped: [Double] = []) -> AccountUsage {
    AccountUsage(
        session: LimitWindow(percent: session, resetsAt: nil, label: "5 hours"),
        weekly: LimitWindow(percent: weekly, resetsAt: nil, label: "Week"),
        scoped: scoped.map { LimitWindow(percent: $0, resetsAt: nil, label: "Model") },
        fetchedAt: Date(),
        staleness: .fresh
    )
}

private let threeAccounts = [
    account(.anthropic, "empty@x.pl"),
    account(.anthropic, "busy@x.pl"),
    account(.anthropic, "full@x.pl"),
]

private let threeUsages: [String: AccountUsage] = [
    "anthropic:empty@x.pl": usage(session: 4),
    "anthropic:busy@x.pl": usage(session: 55),
    "anthropic:full@x.pl": usage(session: 97),
]

@Test func activeAccountReportsSessionAndWeeklyPercent() {
    let readings = MenuBarReading.all(
        accounts: threeAccounts,
        usage: [
            "anthropic:empty@x.pl": usage(session: 12, weekly: 34),
            "anthropic:busy@x.pl": usage(session: 55, weekly: 60),
            "anthropic:full@x.pl": usage(session: 97, weekly: 90),
        ],
        metric: .activeAccount,
        activeEmails: [.anthropic: "busy@x.pl"]
    )
    #expect(readings.count == 1)
    #expect(readings[0].fill == 40)
    #expect(readings[0].text == "45% / 40%")
}

@Test func bestAccountReportsTheEmptiestOne() {
    let readings = MenuBarReading.all(accounts: threeAccounts, usage: threeUsages, metric: .bestAccount)
    #expect(readings.count == 1)
    #expect(readings[0].fill == 96)
    #expect(readings[0].text == "96%")
}

@Test func busiestAccountReportsTheFullestOne() {
    let readings = MenuBarReading.all(accounts: threeAccounts, usage: threeUsages, metric: .worstAccount)
    #expect(readings[0].fill == 3)
    #expect(readings[0].text == "3%")
}

/// The count is of accounts still under the threshold, while the glyph empties as
/// accounts run out — so an empty glyph means "none left".
@Test func accountsWithRoomCountsThemAndFillsAsTheyRunOut() {
    let readings = MenuBarReading.all(accounts: threeAccounts, usage: threeUsages, metric: .accountsWithRoom)
    #expect(readings[0].text == "2")
    let expectedFill = 2.0 / 3.0 * 100
    #expect(abs((readings[0].fill ?? -1) - expectedFill) < 0.001)
}

@Test func anAccountIsJudgedByItsTightestWindow() {
    let readings = MenuBarReading.all(
        accounts: [account(.anthropic, "a@x.pl")],
        usage: ["anthropic:a@x.pl": usage(session: 10, weekly: 71, scoped: [30])],
        metric: .bestAccount
    )
    #expect(readings[0].fill == 29)
}

/// The whole reason readings are a list: one number covering both providers
/// would say a Claude Code account is available when only a Codex one is.
@Test func providersGetSeparateReadings() {
    let readings = MenuBarReading.all(
        accounts: [account(.anthropic, "a@x.pl"), account(.openai, "b@x.pl")],
        usage: [
            "anthropic:a@x.pl": usage(session: 96),
            "openai:b@x.pl": usage(session: 1),
        ],
        metric: .bestAccount
    )
    #expect(readings.count == 2)
    #expect(readings.first(where: { $0.provider == .anthropic })?.fill == 4)
    #expect(readings.first(where: { $0.provider == .openai })?.fill == 99)
}

/// An account nothing is known about must not count as 0% — that would make
/// the menu bar look better than it is precisely when least is known.
@Test func accountsInErrorAreExcludedRatherThanCountedAsZero() {
    let errored = AccountUsage(
        session: .empty, weekly: .empty, scoped: [],
        fetchedAt: Date(), staleness: .error("no connection")
    )
    for metric in MenuBarMetric.allCases {
        let readings = MenuBarReading.all(
            accounts: [account(.anthropic, "a@x.pl"), account(.anthropic, "b@x.pl")],
            usage: ["anthropic:a@x.pl": errored, "anthropic:b@x.pl": usage(session: 62)],
            metric: metric
        )
        switch metric {
        case .activeAccount, .bestAccount, .worstAccount:
            #expect(readings[0].fill == 38)
        case .accountsWithRoom:
            #expect(readings[0].text == "1")
        }
    }
}

@Test func aProviderWithNothingKnownReadsAsEmptyForEveryMetric() {
    for metric in MenuBarMetric.allCases {
        let readings = MenuBarReading.all(
            accounts: [account(.anthropic, "a@x.pl")],
            usage: [:],
            metric: metric
        )
        #expect(readings.count == 1)
        #expect(readings[0].fill == nil)
        #expect(readings[0].text == nil)
    }
}

@Test func aProviderWithNoAccountsGetsNoReading() {
    let readings = MenuBarReading.all(
        accounts: [account(.anthropic, "a@x.pl")],
        usage: ["anthropic:a@x.pl": usage(session: 5)],
        metric: .bestAccount
    )
    #expect(readings.count == 1)
    #expect(readings[0].provider == .anthropic)
}
