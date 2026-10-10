import Foundation

extension Poller {
    /// Refreshes single account's quota, handling renewal, errors and backoff.
    public func refresh(
        account: Account,
        interval: TimeInterval = Poller.baseInterval,
        retryUnauthorized: Bool = true
    ) async -> AccountUsage {
        var current = account
        let hasAntigravitySession = account.provider == .gemini
            && AntigravitySync.hasSavedSignIn(for: account.email)

        if oauth[account.provider] != nil && !hasAntigravitySession {
            do {
                current = try await accountForSwitch(account)
            } catch CredentialError.saveFailed {
                await increaseBackoff(account.id)
                return await lastValueOr(account: account, description: "Could not save the renewed token.")
            } catch OAuthError.invalidGrant {
                if var stored = try? store.load().first(where: { $0.id == account.id }) {
                    stored.needsReauth = true
                    try? store.upsert(stored)
                }
                await increaseBackoff(account.id)
                return await lastValueOr(account: account, description: "Rejected by the provider. Add this account again to renew it.")
            } catch {
                await increaseBackoff(account.id)
                return await lastValueOr(account: account, description: "Could not renew the token.")
            }
        }

        guard let provider = providers[account.provider] else {
            return await lastValueOr(account: account, description: "No client for this provider.")
        }

        let now = await clock()
        lastAttempt[account.id] = now

        do {
            let result = try await provider.fetch(account: current)
            if hasAntigravitySession && current.needsReauth {
                current.needsReauth = false
                try? store.upsert(current)
            }
            cache[account.id] = result
            failureCount[account.id] = 0
            nextDueAt[account.id] = now.addingTimeInterval(max(interval, Self.minimumInterval))
            return result
        } catch UsageError.rateLimited {
            await increaseBackoff(account.id)
            return await lastValueOr(account: account, description: "Rate limited. Trying again later.")
        } catch UsageError.organizationNotAllowed {
            return await handleOrganizationNotAllowed(account: account, current: current)
        } catch UsageError.unavailableQuota where account.provider == .gemini {
            return await handleGeminiUnavailableQuota(account: account, current: current)
        } catch UsageError.unauthorized {
            return await handleUnauthorized(account: account, current: current, interval: interval, retryUnauthorized: retryUnauthorized)
        } catch {
            await increaseBackoff(account.id)
            return await lastValueOr(account: account, description: "No connection.")
        }
    }

    private func handleOrganizationNotAllowed(account: Account, current: Account) async -> AccountUsage {
        if current.needsReauth {
            var cleared = current
            cleared.needsReauth = false
            try? store.upsert(cleared)
        }
        await increaseBackoff(account.id)
        let named = account.organizationName.map { "\"\($0)\"" } ?? "This organisation"
        let description = account.hasSubscription
            ? "\(named) bills per token and reports no subscription limits. This login does have a subscription — the sign-in page put the token on the wrong organisation, and only that page can choose."
            : "\(named) has no Claude subscription to report — it is an API organisation."
        return await lastValueOr(account: account, description: description)
    }

    private func handleGeminiUnavailableQuota(account: Account, current: Account) async -> AccountUsage {
        if current.needsReauth {
            var cleared = current
            cleared.needsReauth = false
            try? store.upsert(cleared)
        }
        await increaseBackoff(account.id)
        return await lastValueOr(
            account: account,
            description: "Sign in with this account in Antigravity once and switch accounts in FuelSwitch to save its session for background quota updates."
        )
    }

    private func handleUnauthorized(account: Account, current: Account, interval: TimeInterval, retryUnauthorized: Bool) async -> AccountUsage {
        if retryUnauthorized, oauth[account.provider] != nil {
            do {
                let renewed = try await accountForSwitch(account, forceTokenRefresh: true)
                return await refresh(account: renewed, interval: interval, retryUnauthorized: false)
            } catch OAuthError.invalidGrant {
            } catch {
                await increaseBackoff(account.id)
                return await lastValueOr(account: account, description: "Could not renew the token.")
            }
        }
        var flagged = current
        flagged.needsReauth = true
        try? store.upsert(flagged)
        await increaseBackoff(account.id)
        return await lastValueOr(account: account, description: "Rejected by the provider. Add this account again to renew it.")
    }
}
