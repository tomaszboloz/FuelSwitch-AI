import Foundation

/// Shortens the poll interval when the CLI was used recently, so a working
/// session sees fresher numbers, without abandoning a user's manually chosen
/// `intervalSeconds` — this only ever divides it down, never overrides it
/// upward, and never goes below `Poller.minimumInterval`.
///
/// "Recent activity" is approximated from the mtime of the CLI credential
/// files (`CLISwitcher.claudeConfigURL`/`.codexAuthURL`/`.geminiConfigURL`).
/// This is imprecise — a token refresh also touches these files — but it's
/// the only activity signal available without watching process lists.
public enum AdaptiveRefreshPolicy {
    public static func effectiveInterval(baseInterval: TimeInterval, sinceLastCliActivity: TimeInterval?) -> TimeInterval {
        let divisor: Double
        switch sinceLastCliActivity {
        case .some(let elapsed) where elapsed < 5 * 60:
            divisor = 4
        case .some(let elapsed) where elapsed < 30 * 60:
            divisor = 2
        default:
            divisor = 1
        }
        return max(baseInterval / divisor, Poller.minimumInterval)
    }
}
