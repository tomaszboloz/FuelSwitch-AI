import SwiftUI
import AppKit
import FuelSwitchCore

struct MenuContentView: View {
    @ObservedObject var model: AppModel
    @State private var listHeight: CGFloat = 0
    @State private var selectedFilter: ProviderFilter = .all

    enum ProviderFilter: Hashable {
        case all
        case anthropic
        case openai
        case gemini

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

    private var filteredAccounts: [Account] {
        switch selectedFilter {
        case .all:
            return model.accounts
        case .anthropic:
            return model.accounts.filter { $0.provider == .anthropic }
        case .openai:
            return model.accounts.filter { $0.provider == .openai }
        case .gemini:
            return model.accounts.filter { $0.provider == .gemini }
        }
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10, alignment: .topLeading),
        GridItem(.flexible(), spacing: 10, alignment: .topLeading),
    ]

    private let panelWidth: CGFloat = 700

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.showingSettings {
                SettingsView(model: model, close: { model.showingSettings = false })
            } else {
                cockpitHeader
                bannerArea
                
                if model.accounts.isEmpty {
                    emptyState
                } else {
                    activeCockpitHero
                    filterToolbar
                    accountsList
                }

                Divider().background(FuelSwitchTheme.borderSubtle)
                cockpitFooter
            }
        }
        .frame(width: panelWidth)
        .background(FuelSwitchTheme.bgDeep)
        .preferredColorScheme(model.colorScheme)
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
        .onAppear {
            model.showingSettings = false
            model.reloadActiveAccounts()
        }
    }

    // MARK: - Cockpit Header
    private var cockpitHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            // FuelSwitch Logo Mark
            ZStack {
                Circle()
                    .fill(FuelSwitchTheme.amber.opacity(0.18))
                    .frame(width: 28, height: 28)
                BrandIcon(size: 28)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(model.t(.appName))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)

                    Circle()
                        .fill(FuelSwitchTheme.emerald)
                        .frame(width: 5, height: 5)
                        .shadow(color: FuelSwitchTheme.emerald.opacity(0.7), radius: 3)
                }

                Text(model.t(.tagline))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }

            Spacer()

            // Header Action Buttons
            HStack(spacing: 8) {
                // Floating Desktop Widget Menu & Toggle
                Menu {
                    Button(model.showFloatingWidget ? model.t(.hudOff) : model.t(.hudOn)) {
                        model.showFloatingWidget.toggle()
                    }
                    Divider()
                    Button("✓ " + model.t(.hudExpanded)) {
                        model.widgetStyle = "expanded"
                        if !model.showFloatingWidget { model.showFloatingWidget = true }
                    }
                    .disabled(model.widgetStyle == "expanded" && model.showFloatingWidget)

                    Button(model.widgetStyle == "compact" ? "✓ " + model.t(.hudCompact) : model.t(.hudCompact)) {
                        model.widgetStyle = "compact"
                        if !model.showFloatingWidget { model.showFloatingWidget = true }
                    }
                    .disabled(model.widgetStyle == "compact" && model.showFloatingWidget)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: model.showFloatingWidget ? "macwindow.on.rectangle" : "macwindow")
                            .font(.system(size: 11))
                        Text(model.showFloatingWidget ? (model.widgetStyle == "compact" ? model.t(.hudCompact) : model.t(.hudOn)) : model.t(.hudOff))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(model.showFloatingWidget ? FuelSwitchTheme.amber.opacity(0.2) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(model.showFloatingWidget ? FuelSwitchTheme.amber.opacity(0.4) : Color.clear, lineWidth: 0.8)
                    )
                    .foregroundStyle(model.showFloatingWidget ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(model.t(.toggleHudHelp))

                // Add Account Menu
                Menu {
                    Button(model.t(.connectClaude)) { model.startLogin(provider: .anthropic) }
                    Button(model.t(.connectCodex)) { model.startLogin(provider: .openai) }
                    Button(model.t(.connectGemini)) { model.startLogin(provider: .gemini) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text(model.t(.addTank))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.08))
                    )
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(isSigningIn)

                // Refresh All
                Button { model.refreshNow() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                        .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                        .animation(model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshing)
                .help(model.isRefreshing ? model.t(.telemetryInProgress) : model.t(.refresh))

                // Settings
                Button { model.showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(model.t(.settings))

                // Quit
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(model.t(.quit))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FuelSwitchTheme.bgPanel)
        .overlay(
            Rectangle()
                .fill(FuelSwitchTheme.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Active Cockpit Hero Section
    private var activeCockpitHero: some View {
        HStack(spacing: 10) {
            heroCard(for: .anthropic, activeEmail: model.activeClaudeEmail)
            heroCard(for: .openai, activeEmail: model.activeCodexEmail)
            heroCard(for: .gemini, activeEmail: model.activeGeminiEmail)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func heroCard(for provider: Provider, activeEmail: String?) -> some View {
        let matchingAccount = model.accounts.first { $0.provider == provider && $0.email.lowercased() == activeEmail?.lowercased() }
        let usage = matchingAccount.flatMap { model.usage[$0.id] }

        let iconColor: Color = {
            switch provider {
            case .anthropic: return Color(red: 0.95, green: 0.60, blue: 0.40)
            case .openai: return Color(red: 0.30, green: 0.85, blue: 0.70)
            case .gemini: return Color(red: 0.35, green: 0.65, blue: 0.98)
            }
        }()
        let iconName: String = {
            switch provider {
            case .anthropic: return "sparkles"
            case .openai: return "terminal.fill"
            case .gemini: return "diamond.fill"
            }
        }()

        return HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 26, height: 26)

                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)

                    if matchingAccount != nil {
                        Text(model.t(.active))
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(FuelSwitchTheme.emerald)
                            .padding(.horizontal, 3)
                            .background(FuelSwitchTheme.emerald.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }

                if let email = activeEmail {
                    Text(email)
                        .font(.system(size: 9))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(model.t(.noActiveCliAccount))
                        .font(.system(size: 9))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }

            Spacer()

            if let usage {
                HStack(spacing: 5) {
                    if usage.isLowFuel {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(FuelSwitchTheme.amber)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(usage.remainingPercent))%")
                            .font(.system(size: 11, weight: .heavy).monospacedDigit())
                            .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: usage.worstPercent))
                        Text(model.t(.remainingFuel))
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(FuelSwitchTheme.textTertiary)
                    }
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(FuelSwitchTheme.bgCardSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(matchingAccount != nil ? FuelSwitchTheme.borderRegular : FuelSwitchTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Filter Toolbar
    private var filterToolbar: some View {
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
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(isSelected ? FuelSwitchTheme.amber.opacity(0.3) : Color.white.opacity(0.08))
                    )
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? FuelSwitchTheme.amber.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isSelected ? FuelSwitchTheme.amber.opacity(0.35) : Color.clear, lineWidth: 0.8)
            )
            .foregroundStyle(isSelected ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Banner Area
    @ViewBuilder
    var bannerArea: some View {
        if let update = model.availableUpdate {
            bannerRow(text: String(format: model.t(.versionAvailable), update.version), tint: FuelSwitchTheme.amber) {
                HStack(spacing: 8) {
                    Button(model.t(.download)) { model.openUpdate() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.amber)
                    Button(model.t(.dismiss)) { model.dismissUpdate() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }
        }

        switch model.loginState {
        case .idle:
            EmptyView()
        case .running(let provider):
            bannerRow(text: String(format: model.t(.connecting), provider.displayName), tint: FuelSwitchTheme.amber) {
                Button(model.t(.cancel)) { model.cancelLogin() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.crimson)
            }
        case .failed(_, let message):
            bannerRow(text: message, tint: FuelSwitchTheme.amber) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .added(let email):
            bannerRow(text: String(format: model.t(.connected), email), tint: FuelSwitchTheme.emerald) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .reconnected(let email):
            bannerRow(text: String(format: model.t(.reconnected), email), tint: FuelSwitchTheme.amber) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .switched(let provider, let email):
            bannerRow(text: String(format: model.t(.switched), provider.displayName, email), tint: FuelSwitchTheme.emerald) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .autoSwitched(let provider, let from, let to):
            bannerRow(text: String(format: model.t(.autoSwitchedBanner), provider.displayName, from, to), tint: FuelSwitchTheme.amber) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private func bannerRow(
        text: String,
        tint: Color,
        @ViewBuilder action: () -> some View
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(2)
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(tint.opacity(0.08))
    }

    // MARK: - Accounts List (Grouped by Provider)
    private struct ProviderGroup: Identifiable {
        let provider: Provider
        let accounts: [Account]
        var id: String { provider.rawValue }
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

    private var accountsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(providerGroups) { group in
                    providerSection(group: group)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ContentHeight.self, value: geo.size.height)
                }
            )
        }
        .frame(height: 380)
    }

    private func providerSection(group: ProviderGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider Section Header
            HStack(spacing: 6) {
                providerIconPill(provider: group.provider)

                Text(group.provider.displayName)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)

                Text("\(group.accounts.count)")
                    .font(.system(size: 9, weight: .heavy).monospacedDigit())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)

                Spacer()

                Button {
                    model.startLogin(provider: group.provider)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                        Text(model.t(.addAccount))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(String(format: model.t(.addProviderAccount), group.provider.displayName))
            }
            .padding(.horizontal, 2)

            // Accounts Grid for this Provider
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(group.accounts) { account in
                    AccountRowView(
                        account: account,
                        usage: model.usage[account.id],
                        isActive: model.isAccountActive(account),
                        onSwitch: { model.switchTo(account: account) },
                        refresh: { model.refreshAccount(id: account.id) },
                        remove: { model.remove(id: account.id) },
                        onRedeemReset: { model.redeemCodexReset(account: account) },
                        paceEnabled: model.paceEstimationEnabled,
                        onRename: { nickname in model.rename(id: account.id, nickname: nickname) }
                    )
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FuelSwitchTheme.bgCard.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(FuelSwitchTheme.borderSubtle.opacity(0.55), lineWidth: 1)
        )
    }

    private func providerIconPill(provider: Provider) -> some View {
        let iconColor: Color = {
            switch provider {
            case .anthropic: return Color(red: 0.95, green: 0.60, blue: 0.40)
            case .openai: return Color(red: 0.30, green: 0.85, blue: 0.70)
            case .gemini: return Color(red: 0.35, green: 0.65, blue: 0.98)
            }
        }()
        let iconName: String = {
            switch provider {
            case .anthropic: return "sparkles"
            case .openai: return "terminal.fill"
            case .gemini: return "diamond.fill"
            }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(iconColor.opacity(0.18))
                .frame(width: 20, height: 20)

            Image(systemName: iconName)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(iconColor)
        }
    }

    // MARK: - Cockpit Footer
    private var cockpitFooter: some View {
        HStack(spacing: 8) {
            Text(String(format: model.t(.accountsCount), model.accounts.count))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.textTertiary)

            Spacer()

            Text(String(format: model.t(.versionLabel), model.currentVersion))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(FuelSwitchTheme.bgPanel)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FuelSwitchTheme.amber.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(FuelSwitchTheme.amber)
            }

            VStack(spacing: 4) {
                Text(model.t(.noAccountsRegistered))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                Text(model.t(.connectMonitor))
                    .font(.system(size: 11))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Button { model.startLogin(provider: .anthropic) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text(model.t(.addClaude))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.amber.opacity(0.18)))
                    .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain)

                Button { model.startLogin(provider: .openai) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "terminal.fill")
                        Text(model.t(.addCodex))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button { model.startLogin(provider: .gemini) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill")
                        Text(model.t(.addGemini))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    var isSigningIn: Bool {
        if case .running = model.loginState { return true }
        return false
    }

    private func sortedAccounts(_ list: [Account]) -> [Account] {
        list.sorted { first, second in
            let firstActive = model.isAccountActive(first)
            let secondActive = model.isAccountActive(second)
            if firstActive != secondActive {
                return firstActive
            }

            let firstUsage = model.usage[first.id]
            let secondUsage = model.usage[second.id]

            let firstPercent: Double = {
                guard let u = firstUsage else { return -1 }
                if case .error = u.staleness { return -1 }
                return u.worstPercent
            }()
            let secondPercent: Double = {
                guard let u = secondUsage else { return -1 }
                if case .error = u.staleness { return -1 }
                return u.worstPercent
            }()

            if firstPercent != secondPercent {
                return firstPercent > secondPercent
            }
            return first.email.localizedCaseInsensitiveCompare(second.email) == .orderedAscending
        }
    }
}

private struct ContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
