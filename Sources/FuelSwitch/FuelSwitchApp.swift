import SwiftUI
import FuelSwitchCore

@main
struct FuelSwitchApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        // One scene, and deliberately so. Adding an account used to open a
        // second window because it needed a text field, and a menu bar panel
        // never becomes the key window. Now there is nothing to type — the
        // provider reports the account's email — so the sign-in runs straight
        // from the panel and the whole class of focus bugs that window brought
        // with it is gone.
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            MenuBarIcon.label(for: model)
        }
        .menuBarExtraStyle(.window)
    }
}
