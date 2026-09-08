import Foundation

public struct AutoSwitchDecision: Equatable, Sendable {
    public let from: Account
    public let to: Account

    public init(from: Account, to: Account) {
        self.from = from
        self.to = to
    }
}

/// Pure decision logic for switching the active CLI account when it runs
/// out of quota. Holds no state and performs no I/O — `AppModel` is
/// responsible for calling `CLISwitcher.switch(to:)` on the result and for
/// the anti-flapping cooldowns, which need wall-clock state this type
/// deliberately does not carry.
public enum AutoSwitchDecider {
    /// Picks the best same-provider replacement for an exhausted active
    /// account, or `nil` when no switch should happen.
    ///
    /// - `exhaustedThreshold`: the active account's `worstPercent` must be
    ///   at or above this to trigger a switch at all. Defaults to 100 —
    ///   only a fully exhausted window forces a switch; a merely low
    ///   account is better handled by the threshold notification, not by
    ///   silently moving the user's session.
    /// - `minimumCandidateRemaining`: a replacement must have at least this
    ///   much capacity left, so the active account is never swapped for
    ///   another account that is itself about to run dry.
    public static func decide(
        provider: Provider,
        accounts: [Account],
        usage: [String: AccountUsage],
        activeEmail: String?,
        exhaustedThreshold: Double = 100,
        minimumCandidateRemaining: Double = 20
    ) -> AutoSwitchDecision? {
        guard let activeEmail,
              let active = accounts.first(where: { $0.provider == provider && $0.email.lowercased() == activeEmail.lowercased() }),
              let activeUsage = usage[active.id],
              activeUsage.worstPercent >= exhaustedThreshold
        else {
            return nil
        }

        let candidates = accounts.filter { candidate in
            candidate.provider == provider
                && candidate.id != active.id
                && !candidate.needsReauth
        }

        let best = candidates
            .compactMap { candidate -> (Account, Double)? in
                // A candidate with no usage yet, or one in an error state,
                // cannot be trusted to actually have quota — exclude it
                // rather than switch onto an unknown.
                guard let candidateUsage = usage[candidate.id] else { return nil }
                if case .error = candidateUsage.staleness { return nil }
                return (candidate, candidateUsage.remainingPercent)
            }
            .filter { $0.1 >= minimumCandidateRemaining }
            .max { $0.1 < $1.1 }

        guard let (winner, _) = best else { return nil }
        return AutoSwitchDecision(from: active, to: winner)
    }
}
