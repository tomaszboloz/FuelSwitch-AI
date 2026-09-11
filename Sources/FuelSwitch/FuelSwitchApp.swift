import SwiftUI
import FuelSwitchCore

@main
struct FuelSwitchApp: App {
    @StateObject private var model = AppModel()

    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"),
           CommandLine.arguments.indices.contains(index + 1) {
            do {
                try TemplatePreviewRenderer.render(to: CommandLine.arguments[index + 1])
                exit(0)
            } catch {
                fputs("Preview rendering failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }

    var body: some Scene {
        // The classic panel stays the default. Native workspace and widgets
        // observe this same model; closing a window does not stop monitoring.
        MenuBarExtra {
            Group {
                if model.interfaceTemplate == .native {
                    VStack(spacing: 12) {
                        Button(model.t(.openMainWindow)) { NativeWindowController.shared.show(model: model) }
                            .keyboardShortcut("o")
                        NativeWidgetView(model: model, onClose: {}, compactOverride: false, showsClose: false)
                            .frame(width: 440, height: 350)
                        Button(model.t(.quit)) { NSApplication.shared.terminate(nil) }
                    }.padding(12)
                } else {
                    MenuContentView(model: model)
                }
            }
                .onOpenURL { model.handleLauncherURL($0) }
        } label: {
            MenuBarIcon.label(for: model)
        }
        .menuBarExtraStyle(.window)
    }
}
