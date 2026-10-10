import SwiftUI

public struct FuelBadge: View {
    public enum BadgeType {
        case active
        case standby
        case exhausted
        case reauth
    }

    public let type: BadgeType
    public let title: String

    public init(type: BadgeType, title: String) {
        self.type = type
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 5, height: 5)
                .shadow(color: indicatorColor.opacity(0.6), radius: 2)

            Text(title)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(indicatorColor.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(indicatorColor.opacity(0.3), lineWidth: 0.8)
        )
        .foregroundStyle(indicatorColor)
    }

    private var indicatorColor: Color {
        switch type {
        case .active: return FuelSwitchTheme.emerald
        case .standby: return FuelSwitchTheme.cyanAccent
        case .exhausted: return FuelSwitchTheme.crimson
        case .reauth: return FuelSwitchTheme.amber
        }
    }
}
