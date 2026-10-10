import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(FuelSwitchTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(FuelSwitchTheme.borderSubtle, lineWidth: 1)
        )
    }
}
