import SwiftUI
import FuelSwitchCore

enum FloatingWidgetTab: Hashable {
    case all
    case provider(Provider)
}

struct FloatingWidgetTabs: View {
    @ObservedObject var model: AppModel
    @Binding var selectedTab: FloatingWidgetTab

    var body: some View {
        HStack(spacing: 4) {
            tabButton(title: model.t(.allActiveTanks), tab: .all, icon: "gauge.with.dots.needle.bottom.50percent")
            ForEach(Provider.allCases) { provider in
                tabButton(title: provider.displayName, tab: .provider(provider), icon: providerIcon(for: provider))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func tabButton(title: String, tab: FloatingWidgetTab, icon: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
                Text(title).font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 7).padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? FuelSwitchTheme.amber.opacity(0.18) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isSelected ? FuelSwitchTheme.amber.opacity(0.4) : Color.clear, lineWidth: 0.8))
            .foregroundStyle(isSelected ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func providerIcon(for provider: Provider) -> String {
        switch provider {
        case .anthropic: "sparkles"
        case .openai: "terminal.fill"
        case .gemini: "diamond.fill"
        }
    }
}
