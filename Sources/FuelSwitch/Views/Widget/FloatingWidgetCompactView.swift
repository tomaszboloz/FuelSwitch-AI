import SwiftUI
import FuelSwitchCore

struct FloatingWidgetCompactView: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(FuelSwitchTheme.bgPanel.opacity(0.94))
                .background(RoundedRectangle(cornerRadius: 10).fill(Material.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FuelSwitchTheme.borderRegular, lineWidth: 1))

            WidgetDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            HStack(spacing: 6) {
                BrandIcon(size: 22)
                    .foregroundStyle(FuelSwitchTheme.amber)
                    .overlay(WidgetDragHandle().accessibilityHidden(true))

                ForEach(Provider.allCases.filter { provider in
                    model.accounts.contains { $0.provider == provider }
                }) { provider in
                    compactProviderPill(provider: provider)
                }

                if model.antigravityLoginAccount != nil {
                    Button { model.openAntigravityLogin() } label: {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                    }.help(model.t(.reauthenticate) + " — Antigravity")
                }
                Spacer(minLength: 4)
                actionsGroup
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 40)
    }

    private var actionsGroup: some View {
        HStack(spacing: 6) {
            Button { model.widgetStyle = "expanded" } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(model.t(.hudExpanded))

            Button { model.openSettings() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(model.t(.settings))

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func compactProviderPill(provider: Provider) -> some View {
        let accounts = model.accounts.filter { $0.provider == provider }
        let activeEmail = model.activeEmail(for: provider)
        let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first
        let usage = activeAccount.flatMap { account in
            account.needsReauth ? nil : model.usage[account.id]
        }
        let isActive = activeAccount.map { model.isAccountActive($0) } ?? false

        return HStack(spacing: 6) {
            providerMenu(provider: provider, accounts: accounts)
            reauthIndicator(activeAccount: activeAccount)
            usageStack(usage: usage)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.bgCard))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? FuelSwitchTheme.amber.opacity(0.4) : FuelSwitchTheme.borderRegular, lineWidth: 1)
        )
    }

    private func providerMenu(provider: Provider, accounts: [Account]) -> some View {
        Menu {
            Text(provider.displayName + ":")
            ForEach(accounts) { acc in
                Button {
                    if acc.needsReauth { model.startLogin(provider: acc.provider) }
                    else { model.switchTo(account: acc) }
                } label: {
                    HStack {
                        Text(acc.email + (acc.needsReauth ? " — " + model.t(.reauthenticate) : ""))
                        if model.isAccountActive(acc) { Text("✓ " + model.t(.active)) }
                    }
                }
            }
            Divider()
            Button(model.t(.addAccount)) { model.startLogin(provider: provider) }
        } label: {
            HStack(spacing: 3) {
                Text(provider.displayName).font(.system(size: 9.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3).fill(FuelSwitchTheme.amber.opacity(0.14)))
        }
        .menuStyle(.borderlessButton).fixedSize()
    }

    @ViewBuilder
    private func reauthIndicator(activeAccount: Account?) -> some View {
        if let activeAccount, activeAccount.needsReauth {
            Button { model.startLogin(provider: activeAccount.provider) } label: {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
            }
            .buttonStyle(.plain).help(model.t(.reauthenticate))
        }
    }

    @ViewBuilder
    private func usageStack(usage: AccountUsage?) -> some View {
        if let usage {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 6) {
                    if usage.isLowFuel {
                        Image(systemName: "fuelpump.fill").font(.system(size: 8.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                    }
                    CompactLimitStack(prefix: "5h:", window: usage.session, now: context.date)
                    CompactLimitStack(prefix: "W:", window: usage.weekly, now: context.date)
                }
            }
        } else {
            Text("—").font(.system(size: 10, weight: .medium)).foregroundStyle(FuelSwitchTheme.textTertiary)
        }
    }
}
