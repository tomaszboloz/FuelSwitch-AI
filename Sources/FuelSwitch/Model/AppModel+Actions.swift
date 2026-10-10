import SwiftUI
import AppKit
import FuelSwitchCore

extension AppModel {
    func redeemCodexReset(account: Account) {
        guard account.provider == .openai,
              !resettingProviders.contains(.openai) else { return }

        resettingProviders.insert(.openai)
        resetResult = nil
        let creditId = usage[account.id]?.resetCreditId

        Task { [weak self] in
            guard let self else { return }
            defer { self.resettingProviders.remove(.openai) }
            do {
                let current = try await self.poller.accountForSwitch(account)
                try await CodexUsageClient().consumeResetCredit(account: current, creditId: creditId)
                await self.poller.forgetState(id: current.id)
                self.usage[current.id] = await self.poller.refresh(account: current, interval: self.intervalSeconds)
                self.loadAccounts()
                self.resetResult = .completed(current.email)
            } catch {
                self.resetResult = .failed(self.resetErrorDescription(error))
            }
        }
    }

    func isResetting(_ account: Account) -> Bool {
        account.provider == .openai && resettingProviders.contains(.openai)
    }

    func dismissResetResult() {
        resetResult = nil
    }

    func resetErrorDescription(_ error: Error) -> String {
        if let usageError = error as? UsageError, usageError == .unauthorized {
            return t(.sessionExpired)
        }
        return t(.resetFailed)
    }

    func openClaudeLimitReset(account: Account) {
        guard account.provider == .anthropic,
              let url = URL(string: "https://claude.ai/settings/usage") else { return }
        NSWorkspace.shared.open(url)
    }

    func checkAutoSwitch(provider: Provider) {
        guard autoSwitchEnabled, !switchingProviders.contains(provider) else { return }
        let now = Date()
        if let manual = lastManualSwitch[provider], now.timeIntervalSince(manual) < Self.manualSwitchGrace { return }
        if let auto = lastAutoSwitch[provider], now.timeIntervalSince(auto) < Self.autoSwitchCooldown { return }

        let activeEmail = activeEmail(for: provider)
        guard let decision = AutoSwitchDecider.decide(
            provider: provider,
            accounts: accounts,
            usage: usage,
            activeEmail: activeEmail
        ) else { return }

        executeAutoSwitch(provider: provider, decision: decision, now: now)
    }

    private func executeAutoSwitch(provider: Provider, decision: AutoSwitchDecision, now: Date) {
        switchingProviders.insert(provider)
        Task {
            defer { switchingProviders.remove(provider) }
            do {
                try await applyAccountSwitch(decision.to)
                lastAutoSwitch[provider] = now
                loginState = .autoSwitched(provider, from: decision.from.email, to: decision.to.email)
                NotificationManager.postAutoSwitchNotification(
                    title: String(format: t(.autoSwitchNotificationTitle), provider.displayName),
                    body: String(format: t(.autoSwitchNotificationBody), decision.from.email, decision.to.email),
                    identifier: "autoswitch|\(provider.rawValue)|\(now.timeIntervalSince1970)"
                )
            } catch {
                lastAutoSwitch[provider] = Date()
                loginState = .failed(provider, switchErrorDescription(error))
            }
        }
    }

    func updateStatuslineCache(account: Account, usage: AccountUsage) {
        guard statuslineEnabled, usage.staleness == .fresh else { return }
        let active = activeEmail(for: account.provider)
        guard active == account.email, let cache = statuslineCaches[account.provider] else { return }

        let snapshot = StatuslineSnapshot(
            provider: account.provider,
            email: account.email,
            sessionPercent: (usage.session.percent * 10).rounded() / 10,
            weeklyPercent: (usage.weekly.percent * 10).rounded() / 10,
            fetchedAt: usage.fetchedAt
        )
        try? cache.write(snapshot)
    }

    func handleLauncherURL(_ url: URL) {
        guard url.scheme == "fuelswitch", url.host == "switch" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let account = accounts.first(where: { $0.id == id }) else { return }
        switchTo(account: account)
    }
}
