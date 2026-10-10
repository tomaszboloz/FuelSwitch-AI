import AppKit
import SwiftUI
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct WidgetViewsTests {
    private func makePreviewModel() -> AppModel {
        AppModel(preview: .classic, previewWidgetStyle: "expanded")
    }

    private func render<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        _ = hosting.fittingSize
        hosting.layout()
    }

    @Test func rendersFloatingWidgetCardAndGauges() {
        let model = makePreviewModel()
        guard let account = model.accounts.first else { return }

        let reauthAccount = Account(provider: .anthropic, email: "reauth@example.com", needsReauth: true)
        let openAIAccount = Account(provider: .openai, email: "codex@example.com")
        let openAIUsage = AccountUsage(
            session: LimitWindow(percent: 95, resetsAt: Date().addingTimeInterval(1800), label: "3h"),
            weekly: LimitWindow(percent: 95, resetsAt: nil, label: "7d"),
            scoped: [], fetchedAt: Date(), staleness: .fresh,
            resetCreditsAvailable: 2
        )
        model.usage[openAIAccount.id] = openAIUsage

        render(FloatingWidgetCard(model: model, account: account, accountsForProvider: [account, reauthAccount]))
        render(FloatingWidgetCard(model: model, account: reauthAccount, accountsForProvider: [account, reauthAccount]))
        render(FloatingWidgetCard(model: model, account: openAIAccount, accountsForProvider: [openAIAccount]))

        render(FloatingWidgetGauges(model: model, usage: model.usage[account.id]))
        render(FloatingWidgetGauges(model: model, usage: nil))
    }

    @Test func rendersCompactLimitStack() {
        let window = LimitWindow(percent: 35, resetsAt: Date().addingTimeInterval(3600), label: "5h")
        render(CompactLimitStack(prefix: "5h", window: window, now: Date()))

        let noResetWindow = LimitWindow(percent: 0, resetsAt: nil, label: "7d")
        render(CompactLimitStack(prefix: "W", window: noResetWindow, now: Date()))
    }

    @Test func rendersGeminiSetupView() {
        let model = makePreviewModel()
        render(GeminiSetupView(model: model, close: {}))
    }

    @Test func rendersUsageHeatmapView() {
        let days = [
            DailyTokenUsage(date: Date().addingTimeInterval(-86400), totalTokens: 5000),
            DailyTokenUsage(date: Date(), totalTokens: 12000)
        ]
        render(UsageHeatmapView(
            days: days,
            isLoading: false,
            loadingText: "Loading...",
            emptyText: "No data",
            summarySuffix: "tokens"
        ))

        render(UsageHeatmapView(
            days: [],
            isLoading: true,
            loadingText: "Loading...",
            emptyText: "No data",
            summarySuffix: "tokens"
        ))

        render(UsageHeatmapView(
            days: [DailyTokenUsage(date: Date(), totalTokens: 0)],
            isLoading: false,
            loadingText: "Loading...",
            emptyText: "No data",
            summarySuffix: "tokens"
        ))
    }
}
