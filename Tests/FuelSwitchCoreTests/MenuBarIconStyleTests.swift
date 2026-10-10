import Testing
@testable import FuelSwitchCore

@Suite struct MenuBarIconStyleTests {
    @Test func everyCaseRoundTripsThroughItsRawValue() {
        for style in MenuBarIconStyle.allCases {
            #expect(MenuBarIconStyle(rawValue: style.rawValue) == style)
            #expect(style.id == style.rawValue)
            #expect(!style.title.isEmpty)
        }
    }

    @Test func anUnknownRawValueFailsToInitializeRatherThanGuessing() {
        #expect(MenuBarIconStyle(rawValue: "somethingRemoved") == nil)
    }
}
