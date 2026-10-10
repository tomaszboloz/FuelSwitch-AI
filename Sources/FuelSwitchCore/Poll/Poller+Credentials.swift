import Foundation

extension Poller {
    enum CredentialError: Error { case saveFailed, removed }

    /// Switching and polling share one token refresh per account.
    public func accountForSwitch(
        _ account: Account,
        forceTokenRefresh: Bool = false
    ) async throws -> Account {
        if let task = credentialRefreshes[account.id] { return try await task.value }
        let store = self.store
        let provider = oauth[account.provider]
        let codexAuthURL = self.codexAuthURL
        let now = await clock()
        if let task = credentialRefreshes[account.id] { return try await task.value }

        let task = Task<Account, Error> {
            guard var current = try store.load().first(where: { $0.id == account.id }) else {
                throw CredentialError.removed
            }
            if current.provider == .openai, let codexAuthURL,
               let newer = try CLISwitcher.newerCodexCredentials(for: current, url: codexAuthURL) {
                current = newer
                try store.upsert(current)
            }
            if current.provider == .anthropic {
                let newer = (try? CLISwitcher.newerClaudeCredentials(for: current)) ?? nil
                if let newer {
                    current = newer
                    try store.upsert(current)
                }
            }
            guard !current.needsReauth else { throw OAuthError.invalidGrant }
            if forceTokenRefresh
                || Self.needsTokenRefresh(account: current, now: now)
                || (current.provider == .openai && current.idToken == nil) {
                guard let provider else { throw OAuthError.invalidGrant }
                let previous = current
                let tokens = try await provider.refresh(refreshToken: current.refreshToken)
                current.accessToken = tokens.accessToken
                current.refreshToken = tokens.refreshToken
                current.expiresAt = tokens.expiresAt
                if let idToken = tokens.idToken { current.idToken = idToken }
                current.needsReauth = false
                guard try store.load().contains(where: { $0.id == current.id }) else {
                    throw CredentialError.removed
                }
                do { try store.upsert(current) } catch { throw CredentialError.saveFailed }
                if current.provider == .openai, let codexAuthURL {
                    try CLISwitcher.syncCodexRefresh(from: previous, to: current, url: codexAuthURL)
                } else if current.provider == .anthropic {
                    try? CLISwitcher.syncClaudeRefresh(from: previous, to: current)
                }
            }
            return current
        }
        credentialRefreshes[account.id] = task
        defer { credentialRefreshes[account.id] = nil }
        return try await task.value
    }
}
