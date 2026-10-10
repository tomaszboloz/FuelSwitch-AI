import AppKit
import SwiftUI
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct UIComponentsTests {
    private let testAccount = Account(
        provider: .anthropic, email: "dev@example.com", plan: "Max",
        accessToken: "t", refreshToken: "r", expiresAt: .distantFuture
    )

    private func render<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        _ = hosting.fittingSize
        hosting.layout()
    }

    @Test func rendersBrandAndFuelIndicators() {
        render(BrandIcon(size: 24))
        render(FuelBadge(type: .active, title: "ACTIVE"))
        render(FuelBadge(type: .standby, title: "STANDBY"))
        render(FuelBadge(type: .exhausted, title: "EMPTY"))
        render(FuelBadge(type: .reauth, title: "REAUTH"))
        render(FuelGauge(value: 75.0, color: .orange, height: 4, showSegments: true))
        render(FuelGauge(value: 40.0, color: .red, height: 4, showSegments: false))
        render(LowFuelIndicator(size: 10, showText: true, text: "LOW FUEL"))
    }

    @Test func rendersAccountRowComponents() {
        let usage = AccountUsage(
            session: LimitWindow(percent: 10, resetsAt: Date(), label: "5h"),
            weekly: LimitWindow(percent: 50, resetsAt: Date(), label: "7d"),
            scoped: [], fetchedAt: Date(), staleness: .fresh
        )

        render(AccountGaugeRow(window: usage.session, now: Date(), paceEnabled: true))

        var editingNickname = false
        var nicknameDraft = ""
        var confirmingRemoval = false
        render(AccountRowHeader(
            account: testAccount,
            usage: usage,
            isActive: true,
            exhausted: false,
            isEditingNickname: Binding(get: { editingNickname }, set: { editingNickname = $0 }),
            nicknameDraft: Binding(get: { nicknameDraft }, set: { nicknameDraft = $0 }),
            confirmingRemoval: Binding(get: { confirmingRemoval }, set: { confirmingRemoval = $0 }),
            onSwitch: {},
            refresh: {},
            onRename: nil,
            commitNickname: {}
        ))

        render(AccountRowActions(
            account: testAccount,
            usage: usage,
            onRedeemReset: {},
            onClaudeReset: {},
            onReauthenticate: {},
            confirmingRemoval: false
        ))

        render(AccountRowView(
            account: testAccount,
            usage: usage,
            isActive: true,
            onSwitch: {},
            refresh: {},
            remove: {}
        ))
    }

    @Test func rendersSettingsCard() {
        let card = SettingsCard(title: "Theme", icon: "paintpalette") {
            Text("Settings Body")
        }
        render(card)
    }
}
