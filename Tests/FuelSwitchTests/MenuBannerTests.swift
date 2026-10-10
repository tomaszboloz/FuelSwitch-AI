import AppKit
import SwiftUI
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct MenuBannerTests {
    private func render<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        _ = hosting.fittingSize
        hosting.layout()
    }

    @Test func rendersResetBanners() {
        let model = AppModel(preview: .classic)

        model.resetResult = .completed("user@example.com")
        render(MenuBannerArea(model: model))

        model.resetResult = .failed("Network timeout during reset")
        render(MenuBannerArea(model: model))

        model.resetResult = nil
        render(MenuBannerArea(model: model))
    }

    @Test func rendersUpdateBanner() {
        let model = AppModel(preview: .classic)
        model.availableUpdate = AvailableUpdate(version: "2.1.0", url: URL(string: "https://example.com/update")!)
        render(MenuBannerArea(model: model))

        model.availableUpdate = nil
        render(MenuBannerArea(model: model))
    }

    @Test func rendersAllLoginStateBanners() {
        let model = AppModel(preview: .classic)

        model.loginState = .idle
        render(MenuBannerArea(model: model))

        model.loginState = .running(.anthropic)
        render(MenuBannerArea(model: model))

        model.loginState = .failed(.gemini, "Authentication rejected")
        render(MenuBannerArea(model: model))

        model.loginState = .added("new@company.com")
        render(MenuBannerArea(model: model))

        model.loginState = .reconnected("existing@company.com")
        render(MenuBannerArea(model: model))

        model.loginState = .switched(.openai, "active@company.com")
        render(MenuBannerArea(model: model))

        model.loginState = .autoSwitched(.anthropic, from: "old@company.com", to: "new@company.com")
        render(MenuBannerArea(model: model))
    }
}
