import AppKit
import SwiftUI
import Testing
import FuelSwitchCore
@testable import FuelSwitch

@MainActor
@Suite struct NativeViewsTests {
    private func makePreviewModel() -> AppModel {
        AppModel(preview: .classic, previewWidgetStyle: "expanded")
    }

    private func render<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: view)
        _ = hosting.fittingSize
        hosting.layout()
    }

    @Test func rendersNativeTemplateView() {
        let model = makePreviewModel()
        render(NativeTemplateView(model: model))
    }

    @Test func rendersNativeAccountDetails() {
        let model = makePreviewModel()
        guard let account = model.accounts.first else { return }

        render(NativeAccountDetails(model: model, account: account))
    }

    @Test func rendersNativeFuelWindow() {
        let model = makePreviewModel()
        let window = LimitWindow(percent: 85, resetsAt: Date().addingTimeInterval(1800), label: "5h")

        render(NativeFuelWindow(model: model, window: window, showsReset: true))

        let lowFuelWindow = LimitWindow(percent: 95, resetsAt: nil, label: "5h")
        render(NativeFuelWindow(model: model, window: lowFuelWindow, showsReset: false))

        render(NativeFuelWindow(model: model, window: nil, showsReset: true))
    }
}
