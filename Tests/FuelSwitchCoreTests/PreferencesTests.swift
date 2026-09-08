import Testing
import Foundation
@testable import FuelSwitchCore

/// `UserDefaults(suiteName:)` with a random name per test — never `.standard`,
/// which holds the user's real settings. Cleaned up after each test by the name
/// remembered at creation (not `.description`, which does not return it in a
/// form `removePersistentDomain` accepts).
private func tempDefaults() -> (defaults: UserDefaults, name: String) {
    let name = UUID().uuidString
    return (UserDefaults(suiteName: name)!, name)
}

@Test func readsTheNewKeyWhenPresent() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(false, forKey: "showPercentInMenuBar")

    #expect(Preferences(defaults: defaults).showsPercentInMenuBar == false)
}

@Test func fallsBackToTheOldKeyWhenTheNewOneIsMissing() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(false, forKey: "pokazujProcent")

    #expect(Preferences(defaults: defaults).showsPercentInMenuBar == false)
}

@Test func aValueBelow60sIsClampedOnRead() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(30.0, forKey: "refreshInterval")

    #expect(Preferences(defaults: defaults).refreshIntervalSeconds == 60)
}

@Test func aValueBelow60sIsClampedOnWrite() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    preferences.refreshIntervalSeconds = 30

    #expect(preferences.refreshIntervalSeconds == 60)
    #expect(defaults.object(forKey: "refreshInterval") as? Double == 60)
}

@Test func migrateRemovesTheOldKey() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(true, forKey: "pokazujProcent")
    defaults.set(600.0, forKey: "interwal")

    Preferences(defaults: defaults).migrate()

    #expect(defaults.object(forKey: "pokazujProcent") == nil)
    #expect(defaults.object(forKey: "interwal") == nil)
    #expect(defaults.object(forKey: "showPercentInMenuBar") as? Bool == true)
    #expect(defaults.object(forKey: "refreshInterval") as? Double == 600)
}

@Test func migrateDoesNotOverwriteAnExistingNewValue() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(false, forKey: "pokazujProcent")
    defaults.set(true, forKey: "showPercentInMenuBar")

    Preferences(defaults: defaults).migrate()

    #expect(defaults.object(forKey: "showPercentInMenuBar") as? Bool == true)
}

@Test func theMenuBarMetricDefaultsToTheActiveAccount() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(Preferences(defaults: defaults).menuBarMetric == .activeAccount)
}

@Test func theMenuBarMetricSurvivesAWriteAndAnUnknownValue() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    preferences.menuBarMetric = .accountsWithRoom
    #expect(preferences.menuBarMetric == .accountsWithRoom)

    // A metric written by a version that had one we no longer do must not
    // leave the menu bar with nothing to show.
    defaults.set("somethingRemoved", forKey: "menuBarMetric")
    #expect(preferences.menuBarMetric == .activeAccount)
}

@Test func theMenuBarIconStyleDefaultsToGauge() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(Preferences(defaults: defaults).menuBarIconStyle == .gauge)
}

@Test func theMenuBarIconStyleSurvivesAWriteAndAnUnknownValue() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    preferences.menuBarIconStyle = .battery
    #expect(preferences.menuBarIconStyle == .battery)

    // A style written by a version that had one we no longer do must not
    // leave the menu bar with nothing to draw.
    defaults.set("somethingRemoved", forKey: "menuBarIconStyle")
    #expect(preferences.menuBarIconStyle == .gauge)
}

@Test func floatingWidgetPreferencesDefaultAndClamp() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    #expect(preferences.showFloatingWidget == false)
    #expect(preferences.widgetOpacity == 0.90)
    #expect(preferences.widgetAlwaysOnTop == true)

    preferences.showFloatingWidget = true
    preferences.widgetOpacity = 0.55
    preferences.widgetAlwaysOnTop = false

    #expect(preferences.showFloatingWidget == true)
    #expect(preferences.widgetOpacity == 0.55)
    #expect(preferences.widgetAlwaysOnTop == false)

    // Clamping opacity
    preferences.widgetOpacity = 0.1
    #expect(preferences.widgetOpacity == 0.3)
    preferences.widgetOpacity = 1.5
    #expect(preferences.widgetOpacity == 1.0)
}

@Test func appThemeDefaultsToSystemAndPersists() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    #expect(preferences.appTheme == "system")
    preferences.appTheme = "dark"
    #expect(preferences.appTheme == "dark")
    preferences.appTheme = "light"
    #expect(preferences.appTheme == "light")
}

@Test func widgetStyleDefaultsToExpandedAndPersists() {
    let (defaults, name) = tempDefaults()
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)

    #expect(preferences.widgetStyle == "expanded")
    preferences.widgetStyle = "compact"
    #expect(preferences.widgetStyle == "compact")
}

