import SwiftUI
import FuelSwitchCore

extension AppModel {
    func configurePreview(_ preview: InterfaceTemplate, style: String) {
        isPreview = true
        interfaceTemplate = preview
        widgetStyle = style
        appTheme = "system"
        accounts = Provider.allCases.map { Account(provider: $0, email: "account@\($0.rawValue).example", nickname: $0.displayName) }
        for (index, account) in accounts.enumerated() {
            usage[account.id] = AccountUsage(
                session: LimitWindow(percent: [38.0, 84, 0][index], resetsAt: .now.addingTimeInterval(7200), label: "5h"),
                weekly: LimitWindow(percent: [57.0, 42, 57][index], resetsAt: .now.addingTimeInterval(86400), label: "7d"),
                scoped: [], fetchedAt: .now, staleness: .fresh)
        }
        activeClaudeEmail = accounts[0].email
        activeCodexEmail = accounts[1].email
        activeGeminiEmail = accounts[2].email
    }

    func configureStandardLaunch() {
        for legacyDir in AccountStore.legacyDirectories {
            _ = try? StoreMigration.run(from: legacyDir, to: AccountStore.defaultDirectory)
        }
        preferences.migrate()
        loadAccounts()
        startLoop()
        updateThemeAppearance()
        FloatingWidgetController.shared.configure(with: self)
        isStatuslineInstalled = statuslineInstaller.isInstalled
        if usageHeatmapEnabled { loadUsageHeatmap() }
        sparkleUpdater.automaticallyChecksForUpdates = sparkleAutoCheckEnabled
        sparkleUpdater.automaticallyDownloadsUpdates = sparkleAutoDownloadEnabled
        sparkleUpdater.start()

        LocalizationManager.shared.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func displayUsage(for account: Account) -> AccountUsage? {
        guard !account.needsReauth, let snapshot = usage[account.id] else { return nil }
        if case .error = snapshot.staleness { return nil }
        return snapshot
    }

    var menuBarReadings: [MenuBarReading] {
        var activeEmails: [Provider: String] = [:]
        if let activeClaudeEmail { activeEmails[.anthropic] = activeClaudeEmail }
        if let activeCodexEmail { activeEmails[.openai] = activeCodexEmail }
        if let activeGeminiEmail { activeEmails[.gemini] = activeGeminiEmail }
        return MenuBarReading.all(
            accounts: accounts,
            usage: usage,
            metric: menuBarMetric,
            activeEmails: activeEmails
        )
    }
}
