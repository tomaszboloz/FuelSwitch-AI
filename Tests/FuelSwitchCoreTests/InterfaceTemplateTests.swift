import Foundation
import Testing
@testable import FuelSwitchCore

@Test func templateDefaultsToClassicIncludingUnknownValues() {
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)
    #expect(preferences.interfaceTemplate == .classic)
    defaults.set("future-template", forKey: "interfaceTemplate")
    #expect(preferences.interfaceTemplate == .classic)
}

@Test func templatePersistsWithoutChangingAppearanceOrAccountSync() {
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let preferences = Preferences(defaults: defaults)
    preferences.appTheme = "dark"
    preferences.widgetStyle = "compact"
    preferences.codexDesktopSyncEnabled = false
    for template in InterfaceTemplate.allCases {
        preferences.interfaceTemplate = template
        #expect(Preferences(defaults: defaults).interfaceTemplate == template)
        #expect(preferences.appTheme == "dark")
        #expect(preferences.widgetStyle == "compact")
        #expect(!preferences.codexDesktopSyncEnabled)
    }
}

@Test func nativeCompactWidgetRemainsAHorizonalBarWithRoomForNumbers() {
    let bounds = FloatingWidgetLayout.bounds(forCompact: true, template: .native)
    #expect(bounds.minSize.width >= 860)
    #expect(bounds.maxSize.height == 70)
    #expect(bounds.minSize.height == bounds.maxSize.height)
    #expect(FloatingWidgetLayout.bounds(forCompact: true, template: .classic) == FloatingWidgetLayout.compactBounds)
}
