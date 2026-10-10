import SwiftUI

/// Amber warning indicator with gas tank icon signaling < 20% remaining fuel.
public struct LowFuelIndicator: View {
    public var size: CGFloat = 11
    public var showText: Bool = false
    public var text: String? = nil

    public init(size: CGFloat = 11, showText: Bool = false, text: String? = nil) {
        self.size = size
        self.showText = showText
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 3.5) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(FuelSwitchTheme.amber)
                .shadow(color: FuelSwitchTheme.amber.opacity(0.5), radius: 2)

            if showText, let text {
                Text(text)
                    .font(.system(size: 8.5, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.amber)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(FuelSwitchTheme.amber.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(FuelSwitchTheme.amber.opacity(0.40), lineWidth: 0.8)
        )
    }
}
