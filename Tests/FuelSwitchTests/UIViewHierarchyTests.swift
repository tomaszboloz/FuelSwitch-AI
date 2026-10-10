import AppKit
import SwiftUI
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct UIViewHierarchyTests {
    private func makePreviewModel() -> AppModel {
        AppModel(preview: .classic, previewWidgetStyle: "expanded")
    }

    private func render<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        _ = hosting.fittingSize
        hosting.layout()
    }

    @Test func rendersSettingsSections() {
        let model = makePreviewModel()

        render(SettingsAppearanceSection(model: model))

        model.showFloatingWidget = false
        render(SettingsWidgetSection(model: model))
        model.showFloatingWidget = true
        render(SettingsWidgetSection(model: model))

        render(SettingsMenuBarSection(model: model))

        model.notificationsEnabled = false
        render(SettingsAutomationSection(model: model))
        model.notificationsEnabled = true
        render(SettingsAutomationSection(model: model))

        render(SettingsIntegrationsSection(model: model))

        model.justConfirmedUpToDate = true
        render(SettingsSecuritySection(model: model))
        model.justConfirmedUpToDate = false
        model.updateCheckFailed = true
        render(SettingsSecuritySection(model: model))

        render(SettingsToolsSection(model: model))

        model.launchAtLoginProblem = "Test permission problem"
        render(SettingsSyncSection(model: model))

        render(SettingsView(model: model, close: {}))
    }

    @Test func rendersMenuComponents() {
        let model = makePreviewModel()

        render(MenuCockpitHeader(model: model, isSigningIn: false))
        render(MenuCockpitHeader(model: model, isSigningIn: true))
        render(MenuCockpitHero(model: model))
        render(MenuBannerArea(model: model))

        var filterVal: ProviderFilter = .all
        let binding = Binding(get: { filterVal }, set: { filterVal = $0 })
        render(MenuFilterToolbar(model: model, selectedFilter: binding))

        render(MenuAccountsList(model: model, selectedFilter: .all, isSigningIn: false))
        render(MenuAccountsList(model: model, selectedFilter: .anthropic, isSigningIn: false))
        render(MenuAccountsList(model: model, selectedFilter: .openai, isSigningIn: false))
        render(MenuAccountsList(model: model, selectedFilter: .gemini, isSigningIn: false))
        render(MenuAccountsList(model: model, selectedFilter: .all, isSigningIn: true))

        render(MenuEmptyState(model: model))
        render(MenuContentView(model: model))
    }

    @Test func rendersWidgetComponents() {
        let model = makePreviewModel()

        render(FloatingWidgetHeader(model: model, onClose: {}))

        var tab: FloatingWidgetTab = .all
        let tabBinding = Binding(get: { tab }, set: { tab = $0 })
        render(FloatingWidgetTabs(model: model, selectedTab: tabBinding))

        render(FloatingWidgetCompactView(model: model, onClose: {}))
        render(FloatingWidgetView(model: model, onClose: {}))
        render(NativeWidgetView(model: model, onClose: {}))
    }
}
