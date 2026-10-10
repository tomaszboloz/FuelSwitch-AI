import Testing
import Foundation
@testable import FuelSwitchCore

@Suite struct PreferencesAllKeysTests {
    private func makeCleanPreferences() -> (Preferences, UserDefaults) {
        let suiteName = "test.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let prefs = Preferences(defaults: defaults)
        return (prefs, defaults)
    }

    @Test func defaultValuesForAutomationPreferences() {
        let (prefs, _) = makeCleanPreferences()
        #expect(prefs.notificationsEnabled == false)
        #expect(prefs.notificationThresholds == [75, 90, 95])
        #expect(prefs.notificationSoundEnabled == true)
        #expect(prefs.autoSwitchEnabled == false)
        #expect(prefs.paceEstimationEnabled == true)
    }

    @Test func mutateAutomationPreferences() {
        let (prefs, _) = makeCleanPreferences()
        prefs.notificationsEnabled = true
        #expect(prefs.notificationsEnabled == true)

        prefs.notificationThresholds = [50, 80, 99]
        #expect(prefs.notificationThresholds == [50, 80, 99])

        prefs.notificationSoundEnabled = false
        #expect(prefs.notificationSoundEnabled == false)

        prefs.autoSwitchEnabled = true
        #expect(prefs.autoSwitchEnabled == true)

        prefs.paceEstimationEnabled = false
        #expect(prefs.paceEstimationEnabled == false)
    }

    @Test func defaultValuesForIntegrationPreferences() {
        let (prefs, _) = makeCleanPreferences()
        #expect(prefs.codexDesktopSyncEnabled == false)
        #expect(prefs.antigravitySyncEnabled == true)
        #expect(prefs.statuslineEnabled == false)
        #expect(prefs.adaptiveRefreshEnabled == false)
        #expect(prefs.usageHeatmapEnabled == false)
        #expect(prefs.sparkleAutoCheckEnabled == false)
        #expect(prefs.sparkleAutoDownloadEnabled == false)
    }

    @Test func mutateIntegrationPreferences() {
        let (prefs, _) = makeCleanPreferences()
        prefs.codexDesktopSyncEnabled = true
        #expect(prefs.codexDesktopSyncEnabled == true)

        prefs.antigravitySyncEnabled = false
        #expect(prefs.antigravitySyncEnabled == false)

        prefs.statuslineEnabled = true
        #expect(prefs.statuslineEnabled == true)

        prefs.adaptiveRefreshEnabled = true
        #expect(prefs.adaptiveRefreshEnabled == true)

        prefs.usageHeatmapEnabled = true
        #expect(prefs.usageHeatmapEnabled == true)

        prefs.sparkleAutoCheckEnabled = true
        #expect(prefs.sparkleAutoCheckEnabled == true)

        prefs.sparkleAutoDownloadEnabled = true
        #expect(prefs.sparkleAutoDownloadEnabled == true)
    }

    @Test func widgetPreferencesMutation() {
        let (prefs, _) = makeCleanPreferences()
        #expect(prefs.widgetStyle == "expanded")
        #expect(prefs.showFloatingWidget == false)
        #expect(prefs.widgetOpacity == 0.90)
        #expect(prefs.widgetAlwaysOnTop == true)

        prefs.widgetStyle = "compact"
        #expect(prefs.widgetStyle == "compact")

        prefs.showFloatingWidget = true
        #expect(prefs.showFloatingWidget == true)

        prefs.widgetOpacity = 0.75
        #expect(prefs.widgetOpacity == 0.75)

        prefs.widgetOpacity = 0.1 // Clamped to 0.3
        #expect(prefs.widgetOpacity == 0.3)

        prefs.widgetAlwaysOnTop = false
        #expect(prefs.widgetAlwaysOnTop == false)
    }
}
