import SwiftUI
import FuelSwitchCore

/// The Floating Desktop HUD Widget for FuelSwitch AI.
/// Supports Expanded Dashboard & Compact Mini-Bar styles.
struct FloatingWidgetView: View {
    @Bindable var model: AppModel
    let onClose: () -> Void

    enum Tab: Hashable {
        case all
        case provider(Provider)
    }

    @State private var selectedTab: Tab = .all

    init(model: AppModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if model.widgetStyle == "compact" {
                compactBody
            } else {
                expandedBody
            }
        }
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    // MARK: - Compact Mini-Bar Style
    private var compactBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(FuelSwitchTheme.bgPanel.opacity(0.94))
                .background(RoundedRectangle(cornerRadius: 10).fill(Material.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(FuelSwitchTheme.borderRegular, lineWidth: 1))

            HStack(spacing: 6) {
                // Drag Handle / Logo
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)

                // Do not spend the compact layout on providers that have no
                // account. Each visible provider shows both normalized limits.
                ForEach(Provider.allCases.filter { provider in
                    model.accounts.contains { $0.provider == provider }
                }) { provider in
                    compactProviderPill(provider: provider)
                }

                Spacer(minLength: 4)

                // Switch to Expanded Mode
                Button {
                    model.widgetStyle = "expanded"
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(model.t(.hudExpanded))

                // Settings Button
                Button {
                    model.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .help(model.t(.settings))

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(minHeight: 40)
    }

    private func compactWindowStack(prefix: String, window: LimitWindow, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Text(prefix)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                Text("\(Int(window.remainingPercent))%")
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: window.percent))
            }
            if let resetsAt = window.resetsAt {
                Text(ResetFormatter.string(for: resetsAt, now: now))
                    .font(.system(size: 7, weight: .medium).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private func compactProviderPill(provider: Provider) -> some View {
        let accounts = model.accounts.filter { $0.provider == provider }
        let activeEmail = activeEmail(for: provider)
        let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first
        let usage = activeAccount.flatMap { model.usage[$0.id] }
        let isActive = activeAccount.map { model.isAccountActive($0) } ?? false

        return HStack(spacing: 6) {
            // Provider switcher menu
            Menu {
                Text(provider.displayName + ":")
                ForEach(accounts) { acc in
                    Button {
                        model.switchTo(account: acc)
                    } label: {
                        HStack {
                            Text(acc.email)
                            if model.isAccountActive(acc) {
                                Text("✓ " + model.t(.active))
                            }
                        }
                    }
                }
                Divider()
                Button(model.t(.addAccount)) {
                    model.startLogin(provider: provider)
                }
            } label: {
                HStack(spacing: 3) {
                    Text(provider.displayName)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FuelSwitchTheme.amber.opacity(0.14))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if let usage {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    HStack(spacing: 6) {
                        if usage.isLowFuel {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(FuelSwitchTheme.amber)
                        }

                        // First: 5h
                        compactWindowStack(prefix: "5h:", window: usage.session, now: context.date)

                        // Second: Week (W)
                        compactWindowStack(prefix: "W:", window: usage.weekly, now: context.date)
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(FuelSwitchTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isActive ? FuelSwitchTheme.amber.opacity(0.4) : FuelSwitchTheme.borderRegular,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Expanded Dashboard Style
    private var expandedBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(FuelSwitchTheme.bgPanel.opacity(0.92))
                .background(RoundedRectangle(cornerRadius: 14).fill(Material.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(FuelSwitchTheme.borderRegular, lineWidth: 1))

            VStack(spacing: 0) {
                header
                Divider().background(FuelSwitchTheme.borderSubtle)

                if model.accounts.isEmpty {
                    emptyState
                } else {
                    tabsBar
                    ScrollView {
                        contentArea
                            .padding(.vertical, 2)
                    }
                }

                Spacer(minLength: 0)
                Divider().background(FuelSwitchTheme.borderSubtle).padding(.top, 4)
                footer
            }
            .padding(12)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(FuelSwitchTheme.amber.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)
            }

            Text(model.t(.hudTitle))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FuelSwitchTheme.textPrimary)

            Spacer()

            // Quick Switcher Menu
            Menu {
                Button(model.t(.connectClaude)) { model.startLogin(provider: .anthropic) }
                Button(model.t(.connectCodex)) { model.startLogin(provider: .openai) }
                Button(model.t(.connectGemini)) { model.startLogin(provider: .gemini) }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FuelSwitchTheme.amber)
            }
            .menuStyle(.borderlessButton)
            .help(model.t(.addAccount))

            // Refresh Button
            Button {
                model.refreshNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isRefreshing)
            }
            .buttonStyle(.plain)
            .help(model.t(.refresh))

            // Switch to Compact Mini-Bar Mode
            Button {
                model.widgetStyle = "compact"
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(model.t(.hudCompact))

            // Settings Button
            Button {
                model.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(model.t(.settings))

            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Tabs Bar
    private var tabsBar: some View {
        HStack(spacing: 4) {
            tabButton(title: model.t(.allActiveTanks), tab: .all, icon: "gauge.with.dots.needle.bottom.50percent")
            ForEach(Provider.allCases) { provider in
                tabButton(title: provider.displayName, tab: .provider(provider), icon: providerIcon(for: provider))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func tabButton(title: String, tab: Tab, icon: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? FuelSwitchTheme.amber.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isSelected ? FuelSwitchTheme.amber.opacity(0.4) : Color.clear, lineWidth: 0.8)
            )
            .foregroundStyle(isSelected ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .all:
            allActiveTanksView
        case .provider(let provider):
            singleProviderView(provider: provider)
        }
    }

    // All Active Tanks View
    private var allActiveTanksView: some View {
        VStack(spacing: 8) {
            ForEach(Provider.allCases) { provider in
                let accounts = model.accounts.filter { $0.provider == provider }
                let activeEmail = activeEmail(for: provider)
                let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first

                if let account = activeAccount {
                    accountCardView(account: account, accountsForProvider: accounts)
                }
            }
        }
    }

    // Single Provider View
    private func singleProviderView(provider: Provider) -> some View {
        let accounts = model.accounts.filter { $0.provider == provider }
        let activeEmail = activeEmail(for: provider)
        let activeAccount = accounts.first { $0.email.lowercased() == activeEmail?.lowercased() } ?? accounts.first

        return Group {
            if let account = activeAccount {
                VStack(spacing: 8) {
                    accountCardView(account: account, accountsForProvider: accounts)
                    if accounts.count > 1 {
                        otherAccountsList(accounts: accounts.filter { $0.id != account.id })
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Text(model.t(.noProviderAccounts))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                    Button(model.t(.addAccount)) {
                        model.startLogin(provider: provider)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)
                }
                .padding(.vertical, 20)
            }
        }
    }

    private func accountCardView(account: Account, accountsForProvider: [Account]) -> some View {
        let usage = model.usage[account.id]
        let isActiveInCLI = model.isAccountActive(account)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(account.provider.monogram)
                    .font(.system(size: 8.5, weight: .heavy))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 2)
                    .background(isActiveInCLI ? FuelSwitchTheme.amber.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundStyle(isActiveInCLI ? FuelSwitchTheme.amber : FuelSwitchTheme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.email)
                        .font(.system(size: 11, weight: isActiveInCLI ? .bold : .semibold))
                        .foregroundStyle(isActiveInCLI ? FuelSwitchTheme.textPrimary : FuelSwitchTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let plan = account.plan {
                        Text(plan.uppercased())
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(FuelSwitchTheme.textTertiary)
                    }
                }

                Spacer()

                if let usage, usage.isLowFuel {
                    LowFuelIndicator(size: 9, showText: true, text: LocalizationManager.shared.text(.lowFuelWarningShort))
                }

                if isActiveInCLI {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(FuelSwitchTheme.emerald)
                            .frame(width: 5, height: 5)
                        Text(model.t(.active))
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(FuelSwitchTheme.emerald)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(FuelSwitchTheme.emerald.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Button(model.t(.engage)) {
                        model.switchTo(account: account)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 8.5, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FuelSwitchTheme.amber.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8)
                    )
                    .foregroundStyle(FuelSwitchTheme.amber)
                }

                // Switch dropdown
                if accountsForProvider.count > 1 {
                    Menu {
                        Text(model.t(.switchTank) + ":")
                        ForEach(accountsForProvider) { candidate in
                            Button {
                                model.switchTo(account: candidate)
                            } label: {
                                HStack {
                                    Text(candidate.email)
                                    if model.isAccountActive(candidate) {
                                        Text("✓ " + model.t(.active))
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(FuelSwitchTheme.amber)
                            .padding(4)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            // OpenAI Codex Reset indicator & action - always visible for Codex
            if account.provider == .openai {
                let credits = max(1, usage?.resetCreditsAvailable ?? 1)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(FuelSwitchTheme.amber)
                        Text(String(format: model.t(.removeCredit), credits))
                            .font(.system(size: 8.5, weight: .heavy).monospacedDigit())
                            .foregroundStyle(FuelSwitchTheme.amber)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(FuelSwitchTheme.amber.opacity(0.15)))

                    Spacer()

                    Button {
                        model.redeemCodexReset(account: account)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 7.5, weight: .bold))
                            Text(model.t(.resetLimit))
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(FuelSwitchTheme.emerald.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(FuelSwitchTheme.emerald.opacity(0.4), lineWidth: 0.8)
                        )
                        .foregroundStyle(FuelSwitchTheme.emerald)
                    }
                    .buttonStyle(.plain)
                    .help(model.t(.redeemResetHelp))
                }
            }

            // Gauges - Stacked Vertically (one under another)
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let now = context.date
                if let usage {
                    VStack(spacing: 5) {
                        gaugeItem(title: model.t(.fiveHourSession), window: usage.session, now: now)
                        gaugeItem(title: model.t(.weeklyQuota), window: usage.weekly, now: now)
                    }
                } else {
                    Text(model.t(.waitingTelemetry))
                        .font(.system(size: 9.5))
                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActiveInCLI ? FuelSwitchTheme.bgCard : FuelSwitchTheme.bgCard.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isActiveInCLI ? FuelSwitchTheme.amber.opacity(0.4) : FuelSwitchTheme.borderSubtle.opacity(0.5),
                    lineWidth: isActiveInCLI ? 1.2 : 0.8
                )
        )
    }

    private func gaugeItem(title: String, window: LimitWindow, now: Date) -> some View {
        let remaining = max(0, min(100, 100.0 - window.percent))
        let isLow = remaining < 20.0
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)

                if isLow {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.amber)
                }

                Spacer()

                if let resetsAt = window.resetsAt {
                    let resetText = title == model.t(.fiveHourSession)
                        ? ResetFormatter.string(for: resetsAt, now: now, includeSeconds: true)
                        : ResetFormatter.string(for: resetsAt, now: now)

                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 7))
                        Text(resetText)
                            .font(.system(size: 8.5).monospacedDigit())
                    }
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                }

                Text("\(Int(remaining))%")
                    .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: window.percent))
            }
            FuelGauge(
                value: remaining,
                color: FuelSwitchTheme.fuelColor(percentUsed: window.percent),
                height: 4,
                showSegments: false
            )
        }
    }

    private func otherAccountsList(accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.t(.allTanks) + " (\(accounts.count))")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                Spacer()
            }
            .padding(.top, 4)

            ForEach(accounts) { acc in
                accountCardView(account: acc, accountsForProvider: accounts)
            }
        }
    }

    // MARK: - Footer
    private var footer: some View {
        HStack {
            Text(String(format: model.t(.tanksCount), model.accounts.count))
                .font(.system(size: 9))
                .foregroundStyle(FuelSwitchTheme.textTertiary)

            Spacer()

            // Language quick badge
            Text(model.localization.currentLanguage.nativeName)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(FuelSwitchTheme.amber)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(FuelSwitchTheme.amber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(model.t(.noAccountsRegistered))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FuelSwitchTheme.textSecondary)
            Button(model.t(.addAccount)) {
                model.startLogin(provider: .anthropic)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(FuelSwitchTheme.amber)
        }
        .padding(.vertical, 24)
    }

    private func activeEmail(for provider: Provider) -> String? {
        switch provider {
        case .anthropic: return model.activeClaudeEmail
        case .openai: return model.activeCodexEmail
        case .gemini: return model.activeGeminiEmail
        }
    }

    private func providerIcon(for provider: Provider) -> String {
        switch provider {
        case .anthropic: return "sparkles"
        case .openai: return "terminal.fill"
        case .gemini: return "diamond.fill"
        }
    }
}
