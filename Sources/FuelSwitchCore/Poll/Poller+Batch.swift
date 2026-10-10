import Foundation

extension Poller {
    /// Checks one account on demand.
    public func refreshOne(
        account: Account,
        interval: TimeInterval = Poller.baseInterval
    ) async -> AccountUsage {
        let now = await clock()
        if let last = lastAttempt[account.id], now.timeIntervalSince(last) < Self.minimumInterval {
            return await lastValueOr(
                account: account,
                description: "Checked moments ago. Waiting before the next one."
            )
        }
        failureCount[account.id] = 0
        return await refresh(account: account, interval: interval)
    }

    /// Spreads requests across accounts, honouring intervals and backoff.
    public func refreshAll(
        interval: TimeInterval = Poller.baseInterval,
        forced: Bool = false,
        onResult: (@MainActor @Sendable (String, AccountUsage) -> Void)? = nil
    ) async -> [String: AccountUsage] {
        let accounts = (try? store.load()) ?? []
        let now = await clock()
        var results: [String: AccountUsage] = [:]
        var previousWasQueried = false

        for account in accounts {
            if forced {
                if let last = lastAttempt[account.id], now.timeIntervalSince(last) < Self.minimumInterval {
                    let result = await lastValueOr(account: account, description: "Checked moments ago. Waiting before the next one.")
                    results[account.id] = result
                    await onResult?(account.id, result)
                    continue
                }
                failureCount[account.id] = 0
            } else if nextDue(for: account) > now {
                let result = await lastValueOr(account: account, description: "Waiting out the backoff after an error.")
                results[account.id] = result
                await onResult?(account.id, result)
                continue
            }
            if previousWasQueried {
                try? await Task.sleep(for: .milliseconds(400))
            }
            previousWasQueried = true
            let result = await refresh(account: account, interval: interval)
            results[account.id] = result
            await onResult?(account.id, result)
        }
        return results
    }
}
