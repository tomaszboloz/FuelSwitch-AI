import SwiftUI
import FuelSwitchCore

extension AppModel {
    func loadAccounts() {
        accounts = (try? store.load()) ?? []
        reloadActiveAccounts()
        loadInitialCachedUsage()
    }

    func loadInitialCachedUsage() {
        guard let activeEmail = activeClaudeEmail else { return }
        let claude = accounts.first { $0.provider == .anthropic && $0.email.lowercased() == activeEmail.lowercased() }
        guard let claudeAccount = claude, usage[claudeAccount.id] == nil,
              let cached = CLISwitcher.cachedClaudeUsage() else { return }
        usage[claudeAccount.id] = cached
    }

    func reloadActiveAccounts() {
        guard !isPreview else { return }
        activeClaudeEmail = CLISwitcher.activeEmail(for: .anthropic, knownAccounts: accounts)
        activeCodexEmail = CLISwitcher.activeEmail(for: .openai, knownAccounts: accounts)
        activeAccountReloadRevision += 1
        let revision = activeAccountReloadRevision
        if antigravitySyncEnabled {
            activeGeminiEmail = nil
            Task {
                let email = await AntigravitySync.runningSignedInEmail()
                guard revision == self.activeAccountReloadRevision, self.antigravitySyncEnabled else { return }
                self.activeGeminiEmail = email
            }
        } else {
            activeGeminiEmail = CLISwitcher.activeEmail(for: .gemini, knownAccounts: accounts)
        }
    }

    func isAccountActive(_ account: Account) -> Bool {
        let active: String?
        switch account.provider {
        case .anthropic: active = activeClaudeEmail
        case .openai: active = activeCodexEmail
        case .gemini: active = activeGeminiEmail
        }
        guard let active else { return false }
        return active.caseInsensitiveCompare(account.email) == .orderedSame
    }

    func switchTo(account: Account) {
        guard !switchingProviders.contains(account.provider) else { return }
        autoDismissBannerTask?.cancel()
        antigravityLoginAccount = nil
        lastManualSwitch[account.provider] = Date()
        switchingProviders.insert(account.provider)
        Task { [weak self] in
            guard let self else { return }
            defer { self.switchingProviders.remove(account.provider) }
            do {
                try await self.applyAccountSwitch(account)
                self.loginState = .switched(account.provider, account.email)
                self.scheduleBannerDismissal()
            } catch {
                if let syncError = error as? AntigravitySync.SyncError,
                   syncError == .signInRequired || syncError == .accountMismatch {
                    self.antigravityLoginAccount = account
                }
                self.loadAccounts()
                self.loginState = .failed(account.provider, self.switchErrorDescription(error))
            }
        }
    }

    func scheduleBannerDismissal() {
        autoDismissBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self else { return }
            if case .switched = self.loginState {
                self.dismissLoginState()
            }
        }
    }

    func switchErrorDescription(_ error: Error) -> String {
        if error is CodexDesktopSync.SyncError { return t(.codexDesktopRestartFailed) }
        if let error = error as? AntigravitySync.SyncError {
            switch error {
            case .signInRequired: return t(.antigravitySignInRequired)
            case .accountMismatch: return t(.antigravityAccountMismatch)
            default: return t(.antigravityRestartFailed)
            }
        }
        if error is OAuthError { return t(.sessionExpired) }
        return t(.operationFailed)
    }

    func applyAccountSwitch(_ account: Account) async throws {
        let syncDesktop = account.provider == .openai && codexDesktopSyncEnabled
        let current = try await poller.accountForSwitch(account)
        if current.provider == .openai { try CLISwitcher.validateCodexSwitch(to: current) }
        let finish = {
            self.loadAccounts()
            if let value = self.usage[current.id] { self.updateStatuslineCache(account: current, usage: value) }
        }
        if current.provider == .gemini {
            try await performGeminiSwitch(current: current, finish: finish)
            return
        }
        try await CodexDesktopSync.performSwitch(enabled: syncDesktop) {
            try CLISwitcher.switch(to: current)
            finish()
        }
    }

    private func performGeminiSwitch(current: Account, finish: @escaping () -> Void) async throws {
        let sync = antigravitySyncEnabled
        let signedIn = sync ? await AntigravitySync.runningSignedInEmail() : nil
        var restored = false
        try await AntigravitySync.performSwitch(enabled: sync, swap: {
            if sync { restored = try AntigravitySync.swapSignIn(to: current.email, currentEmail: signedIn) }
        }, verify: {
            guard restored else { throw AntigravitySync.SyncError.signInRequired }
            try await AntigravitySync.confirmSignedIn(email: current.email)
        })
        try CLISwitcher.switch(to: current)
        finish()
    }

    func remove(id: String) {
        try? store.remove(id: id)
        usage[id] = nil
        loadAccounts()
        Task { await thresholdWatcher.forget(accountId: id) }
    }

    func rename(id: String, nickname: String?) {
        guard var account = accounts.first(where: { $0.id == id }) else { return }
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        account.nickname = (trimmed?.isEmpty ?? true) ? nil : trimmed
        try? store.upsert(account)
        loadAccounts()
    }
}
