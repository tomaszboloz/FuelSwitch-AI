import Testing
@testable import FuelSwitchCore

@Suite struct MenuBarMetricTests {
    @Test func everyCaseHasNonEmptyIdTitleAndExplanation() {
        for metric in MenuBarMetric.allCases {
            #expect(!metric.id.isEmpty)
            #expect(!metric.title.isEmpty)
            #expect(!metric.explanation.isEmpty)
            #expect(MenuBarMetric(rawValue: metric.rawValue) == metric)
        }
    }

    @Test func unknownRawValueReturnsNil() {
        #expect(MenuBarMetric(rawValue: "unknown_metric") == nil)
    }
}
