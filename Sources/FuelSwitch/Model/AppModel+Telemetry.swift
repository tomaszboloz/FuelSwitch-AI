import SwiftUI
import FuelSwitchCore

extension AppModel {
    func refreshNow() {
        Task { await refreshOnce(forced: true) }
    }

    func refreshAccount(id: String) {
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        Task {
            usage[id] = await poller.refreshOne(account: account, interval: intervalSeconds)
            loadAccounts()
        }
    }

    func startLoop() {
        loopTask = Task {
            while !Task.isCancelled {
                await refreshOnce()
                await checkForUpdateIfDue()
                await waitForNextRefresh()
            }
        }
    }

    func waitForNextRefresh() async {
        var elapsed: TimeInterval = 0
        while elapsed < effectiveIntervalSeconds, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            elapsed += 1
        }
    }

    var effectiveIntervalSeconds: TimeInterval {
        guard adaptiveRefreshEnabled else { return intervalSeconds }
        return AdaptiveRefreshPolicy.effectiveInterval(
            baseInterval: intervalSeconds,
            sinceLastCliActivity: timeSinceLastCliActivity()
        )
    }

    func timeSinceLastCliActivity() -> TimeInterval? {
        let urls = [CLISwitcher.claudeConfigURL, CLISwitcher.codexAuthURL, CLISwitcher.geminiOAuthCredsURL]
        let mtimes = urls.compactMap { url -> Date? in
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        }
        guard let mostRecent = mtimes.max() else { return nil }
        return Date().timeIntervalSince(mostRecent)
    }

    func refreshOnce(forced: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        usage = await poller.refreshAll(
            interval: intervalSeconds,
            forced: forced,
            onResult: { [weak self] id, accountUsage in
                guard let self else { return }
                self.usage[id] = accountUsage
                guard let account = self.accounts.first(where: { $0.id == id }) else { return }
                Task { await self.checkThresholds(account: account, usage: accountUsage) }
                self.checkAutoSwitch(provider: account.provider)
                self.updateStatuslineCache(account: account, usage: accountUsage)
            }
        )
        loadAccounts()
        isRefreshing = false
    }

    func checkThresholds(account: Account, usage: AccountUsage) async {
        guard notificationsEnabled, usage.staleness == .fresh,
              isActiveCLIAccount(account) else { return }
        let thresholds = notificationThresholds
        for window in [usage.session, usage.weekly] {
            guard let crossing = await thresholdWatcher.evaluate(
                accountId: account.id,
                windowLabel: window.label,
                percent: window.percent,
                thresholds: thresholds
            ) else { continue }

            let windowName = window.label == "5 hours" ? t(.fiveHourSession) : t(.weeklyQuota)
            NotificationManager.postThresholdNotification(
                accountId: account.id,
                windowLabel: crossing.windowLabel,
                title: String(format: t(.notificationThresholdTitle), account.provider.displayName),
                body: String(format: t(.notificationThresholdBody), windowName, crossing.threshold),
                soundEnabled: notificationSoundEnabled
            )
        }
    }

    func isActiveCLIAccount(_ account: Account) -> Bool {
        let activeEmail: String?
        switch account.provider {
        case .anthropic: activeEmail = activeClaudeEmail
        case .openai: activeEmail = activeCodexEmail
        case .gemini: activeEmail = activeGeminiEmail
        }
        return activeEmail?.caseInsensitiveCompare(account.email) == .orderedSame
    }
}
