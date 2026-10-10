import SwiftUI
import FuelSwitchCore

enum ProviderFilter: Hashable {
    case all, anthropic, openai, gemini

    @MainActor
    func title(model: AppModel) -> String {
        switch self {
        case .all: return model.t(.allTanks)
        case .anthropic: return "Claude"
        case .openai: return "Codex"
        case .gemini: return "Gemini"
        }
    }
}

struct MenuFilterToolbar: View {
    @ObservedObject var model: AppModel
    @Binding var selectedFilter: ProviderFilter

    var body: some View {
        HStack(spacing: 6) {
            filterButton(filter: .all, count: model.accounts.count)
            filterButton(filter: .anthropic, count: model.accounts.filter { $0.provider == .anthropic }.count)
            filterButton(filter: .openai, count: model.accounts.filter { $0.provider == .openai }.count)
            filterButton(filter: .gemini, count: model.accounts.filter { $0.provider == .gemini }.count)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func filterButton(filter: ProviderFilter, count: Int) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 4) {
                Text(filter.title(model: model))
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                Text("\(count)")
                    .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(isSelected ? FuelSwitchTheme.amber.opacity(0.3) : Color.white.opacity(0.08)))
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? FuelSwitchTheme.amber.opacity(0.16) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isSelected ? FuelSwitchTheme.amber.opacity(0.35) : Color.clear, lineWidth: 0.8))
            .foregroundStyle(isSelected ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
