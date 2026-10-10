import SwiftUI
import FuelSwitchCore

/// The Floating Desktop HUD Widget for FuelSwitch AI.
/// Supports Expanded Dashboard & Compact Mini-Bar styles.
struct FloatingWidgetView: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void

    @State private var selectedTab: FloatingWidgetTab = .all

    init(model: AppModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if model.interfaceTemplate == .native {
                NativeWidgetView(model: model, onClose: onClose)
            } else if model.widgetStyle == "compact" {
                FloatingWidgetCompactView(model: model, onClose: onClose)
            } else {
                expandedBody
            }
        }
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    private var expandedBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(FuelSwitchTheme.bgPanel.opacity(0.92))
                .background(RoundedRectangle(cornerRadius: 14).fill(Material.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FuelSwitchTheme.borderRegular, lineWidth: 1))

            WidgetDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                FloatingWidgetHeader(model: model, onClose: onClose)
                MenuContentView(model: model).bannerArea
                Divider().background(FuelSwitchTheme.borderSubtle)

                if model.accounts.isEmpty {
                    emptyState
                } else {
                    FloatingWidgetTabs(model: model, selectedTab: $selectedTab)
                    ScrollView {
                        contentArea.padding(.vertical, 2)
                    }
                }

                Spacer(minLength: 0)
                Divider().background(FuelSwitchTheme.borderSubtle).padding(.top, 4)
                footer
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .all:
            allActiveTanksView
        case .provider(let provider):
            singleProviderView(provider: provider)
        }
    }

    private var allActiveTanksView: some View {
        VStack(spacing: 8) {
            ForEach(Provider.allCases) { provider in
                let accounts = model.accounts.filter { $0.provider == provider }
                let activeEmail = model.activeEmail(for: provider)
                let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first
                if let account = activeAccount {
                    FloatingWidgetCard(model: model, account: account, accountsForProvider: accounts)
                }
            }
        }
    }

    private func singleProviderView(provider: Provider) -> some View {
        let accounts = model.accounts.filter { $0.provider == provider }
        let activeEmail = model.activeEmail(for: provider)
        let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first

        return Group {
            if let account = activeAccount {
                VStack(spacing: 8) {
                    FloatingWidgetCard(model: model, account: account, accountsForProvider: accounts)
                    if accounts.count > 1 {
                        otherAccountsList(accounts: accounts.filter { $0.id != account.id })
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Text(model.t(.noProviderAccounts)).font(.system(size: 11, weight: .medium)).foregroundStyle(FuelSwitchTheme.textSecondary)
                    Button(model.t(.addAccount)) { model.startLogin(provider: provider) }
                        .buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                }
                .padding(.vertical, 20)
            }
        }
    }

    private func otherAccountsList(accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.t(.allTanks) + " (\(accounts.count))").font(.system(size: 9.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.textTertiary)
                Spacer()
            }
            .padding(.top, 4)

            ForEach(accounts) { acc in
                FloatingWidgetCard(model: model, account: acc, accountsForProvider: accounts)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(String(format: model.t(.tanksCount), model.accounts.count)).font(.system(size: 9)).foregroundStyle(FuelSwitchTheme.textTertiary)
            Spacer()
            Text(model.localization.currentLanguage.nativeName)
                .font(.system(size: 8.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                .padding(.horizontal, 4).padding(.vertical, 1.5)
                .background(FuelSwitchTheme.amber.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(model.t(.noAccountsRegistered)).font(.system(size: 11, weight: .medium)).foregroundStyle(FuelSwitchTheme.textSecondary)
            Button(model.t(.addAccount)) { model.startLogin(provider: .anthropic) }
                .buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
        }
        .padding(.vertical, 24)
    }
}
