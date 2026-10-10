import SwiftUI
import AppKit
import FuelSwitchCore

extension AppModel {
    func requiresAntigravityLogin(_ account: Account) -> Bool {
        account.provider == .gemini && antigravitySyncEnabled
            && !isAccountActive(account) && !AntigravitySync.hasSavedSignIn(for: account.email)
    }

    func openAntigravityLogin() {
        Task {
            guard let id = AntigravitySync.bundleIdentifiers.first,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
            try? await CodexDesktopSync.open(url)
        }
    }

    func saveGeminiCredentialsAndConnect(clientID: String, clientSecret: String) {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedSecret.isEmpty else { return }
        try? GeminiClientStore.default.save(
            GeminiClientCredentials(clientID: trimmedID, clientSecret: trimmedSecret)
        )
        GeminiSetupWindowController.shared.close()
        startLogin(provider: .gemini)
    }

    func startLogin(provider: Provider) {
        if provider == .gemini, !FuelSwitchConstants.geminiIsConfigured {
            GeminiSetupWindowController.shared.show(model: self)
            return
        }
        loginTask?.cancel()
        loginState = .running(provider)
        let knownIDs = Set(accounts.map(\.id))
        loginTask = Task { [store] in
            let flow = LoginFlow(store: store) { url in
                NSWorkspace.shared.open(url)
            }
            do {
                let added = try await flow.logIn(provider: provider)
                guard !Task.isCancelled else { return }
                loadAccounts()
                await checkImmediately(added)
                loginState = knownIDs.contains(added.id)
                    ? .reconnected(added.email)
                    : .added(added.email)
            } catch {
                guard !Task.isCancelled else { return }
                loginState = .failed(provider, errorDescription(error, provider: provider))
            }
        }
    }

    func checkImmediately(_ account: Account) async {
        await poller.forgetState(id: account.id)
        await thresholdWatcher.forget(accountId: account.id)
        usage[account.id] = await poller.refresh(account: account, interval: intervalSeconds)
        loadAccounts()
    }

    func dismissLoginState() {
        antigravityLoginAccount = nil
        loginState = .idle
    }

    func cancelLogin() {
        loginTask?.cancel()
        loginTask = nil
        loginState = .idle
    }

    func errorDescription(_ error: Error, provider: Provider) -> String {
        if case LoginFlowError.providerNotConfigured = error {
            return "Gemini sign-in isn't configured yet. Use \"Connect Gemini\" to enter your own Google Cloud OAuth client."
        }
        if case OAuthError.portInUse = error, provider == .openai {
            return "Port 1455 is in use. Quit any running `codex login` and try again."
        }
        if case OAuthError.stateMismatch = error {
            return "The browser's reply does not match this sign-in. Try again."
        }
        if case OAuthError.timedOut = error {
            return "No sign-in came back from the browser within five minutes. Try again."
        }
        if case OAuthError.incompleteCodexIdentity = error {
            return "Codex did not return a complete account identity (email or account id). Try signing in again."
        }
        if error is AnthropicProfileError {
            return "Could not read the Claude account identity. Try again."
        }
        return "Sign-in failed: \(error)"
    }
}
