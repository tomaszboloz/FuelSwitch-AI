import AppKit
import SwiftUI

/// All templates use the same bundled brand asset.
struct BrandIcon: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: "fuelpump.fill").resizable().foregroundStyle(.orange)
            }
        }
        .scaledToFit().frame(width: size, height: size)
        .accessibilityLabel("FuelSwitch AI")
    }
}
