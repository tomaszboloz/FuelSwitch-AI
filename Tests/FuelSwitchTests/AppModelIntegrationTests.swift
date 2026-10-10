import Testing
import Foundation
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct AppModelIntegrationTests {
    @Test func previewModelInitializesWithMockData() {
        let model = AppModel(preview: .classic, previewWidgetStyle: "compact")
        #expect(model.isPreview == true)
        #expect(model.interfaceTemplate == .classic)
        #expect(model.widgetStyle == "compact")
        #expect(model.accounts.count == Provider.allCases.count)

        for provider in Provider.allCases {
            let active = model.activeEmail(for: provider)
            #expect(active != nil)
            let matching = model.accounts.first { $0.provider == provider }
            #expect(matching != nil)
            if let matching {
                #expect(model.isAccountActive(matching) == true)
                #expect(model.displayUsage(for: matching) != nil)
            }
        }
    }

    @Test func menuBarReadingsComputedCorrectlyInPreview() {
        let model = AppModel(preview: .classic)
        let readings = model.menuBarReadings
        #expect(!readings.isEmpty)
        #expect(readings.count == Provider.allCases.count)
    }

    @Test func translationsAndFormatting() {
        let model = AppModel(preview: .classic)
        #expect(!model.t(.appName).isEmpty)
        #expect(!model.t(.connectClaude).isEmpty)
        #expect(!model.t(.connectCodex).isEmpty)
        #expect(!model.t(.connectGemini).isEmpty)
    }

    @Test func updatesThemesAndWidgetStyles() {
        let model = AppModel(preview: .classic)
        model.appTheme = "dark"
        #expect(model.colorScheme == .dark)

        model.appTheme = "light"
        #expect(model.colorScheme == .light)

        model.appTheme = "system"
        #expect(model.colorScheme == nil)

        model.widgetStyle = "compact"
        #expect(model.widgetStyle == "compact")

        model.widgetStyle = "expanded"
        #expect(model.widgetStyle == "expanded")
    }

    @Test func displayUsageRejectsStaleOrErroredAccounts() {
        let model = AppModel(preview: .classic)
        guard let account = model.accounts.first else { return }

        // Needs reauth -> nil
        let reauthAccount = Account(provider: account.provider, email: account.email, needsReauth: true)
        #expect(model.displayUsage(for: reauthAccount) == nil)

        // Error staleness -> nil
        let errorUsage = AccountUsage(
            session: .empty, weekly: .empty, scoped: [],
            fetchedAt: Date(), staleness: .error("Network failure")
        )
        model.usage[account.id] = errorUsage
        #expect(model.displayUsage(for: account) == nil)
    }
}
