import SwiftUI
import FuelSwitchCore

struct MenuAccountsList: View {
    @ObservedObject var model: AppModel
    let selectedFilter: ProviderFilter
    let isSigningIn: Bool

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10, alignment: .topLeading),
        GridItem(.flexible(), spacing: 10, alignment: .topLeading),
    ]

    struct ProviderGroup: Identifiable {
        let provider: Provider
        let accounts: [Account]
        var id: String { provider.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(providerGroups) { group in
                    providerSection(group: group)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 380)
    }

    private var providerGroups: [ProviderGroup] {
        switch selectedFilter {
        case .all:
            return Provider.allCases.compactMap { provider in
                let matching = sortedAccounts(model.accounts.filter { $0.provider == provider })
                guard !matching.isEmpty else { return nil }
                return ProviderGroup(provider: provider, accounts: matching)
            }
        case .anthropic:
            let matching = sortedAccounts(model.accounts.filter { $0.provider == .anthropic })
            return matching.isEmpty ? [] : [ProviderGroup(provider: .anthropic, accounts: matching)]
        case .openai:
            let matching = sortedAccounts(model.accounts.filter { $0.provider == .openai })
            return matching.isEmpty ? [] : [ProviderGroup(provider: .openai, accounts: matching)]
        case .gemini:
            let matching = sortedAccounts(model.accounts.filter { $0.provider == .gemini })
            return matching.isEmpty ? [] : [ProviderGroup(provider: .gemini, accounts: matching)]
        }
    }

    private func providerSection(group: ProviderGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                providerIconPill(provider: group.provider)
                Text(group.provider.displayName).font(.system(size: 11.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
                Text("\(group.accounts.count)").font(.system(size: 9, weight: .heavy).monospacedDigit())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                Spacer()
                Button { model.startLogin(provider: group.provider) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 8, weight: .bold))
                        Text(model.t(.addAccount)).font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(String(format: model.t(.addProviderAccount), group.provider.displayName))
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(group.accounts) { account in
                    AccountRowView(
                        account: account, usage: model.usage[account.id], isActive: model.isAccountActive(account),
                        onSwitch: { model.switchTo(account: account) }, refresh: { model.refreshAccount(id: account.id) },
                        remove: { model.remove(id: account.id) }, onRedeemReset: { model.redeemCodexReset(account: account) },
                        onClaudeReset: { model.openClaudeLimitReset(account: account) },
                        onReauthenticate: { model.startLogin(provider: account.provider) },
                        paceEnabled: model.paceEstimationEnabled,
                        onRename: { nickname in model.rename(id: account.id, nickname: nickname) }
                    )
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(FuelSwitchTheme.bgCard.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FuelSwitchTheme.borderSubtle.opacity(0.55), lineWidth: 1))
    }

    private func providerIconPill(provider: Provider) -> some View {
        let (iconColor, iconName): (Color, String) = {
            switch provider {
            case .anthropic: return (Color(red: 0.95, green: 0.60, blue: 0.40), "sparkles")
            case .openai: return (Color(red: 0.30, green: 0.85, blue: 0.70), "terminal.fill")
            case .gemini: return (Color(red: 0.35, green: 0.65, blue: 0.98), "diamond.fill")
            }
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: 5).fill(iconColor.opacity(0.18)).frame(width: 20, height: 20)
            Image(systemName: iconName).font(.system(size: 9.5, weight: .bold)).foregroundStyle(iconColor)
        }
    }

    private func sortedAccounts(_ list: [Account]) -> [Account] {
        list.sorted { first, second in
            let firstActive = model.isAccountActive(first)
            let secondActive = model.isAccountActive(second)
            if firstActive != secondActive { return firstActive }

            let firstUsage = model.usage[first.id]
            let secondUsage = model.usage[second.id]
            let firstPercent = firstUsage.flatMap { u -> Double? in
                if case .error = u.staleness { return -1 }
                return u.worstPercent
            } ?? -1
            let secondPercent = secondUsage.flatMap { u -> Double? in
                if case .error = u.staleness { return -1 }
                return u.worstPercent
            } ?? -1

            if firstPercent != secondPercent { return firstPercent > secondPercent }
            return first.email.localizedCaseInsensitiveCompare(second.email) == .orderedAscending
        }
    }
}
