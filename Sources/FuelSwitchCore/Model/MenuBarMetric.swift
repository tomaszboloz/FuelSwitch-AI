import Foundation

/// What the one number in the menu bar is supposed to answer.
///
/// These are three genuinely different questions, not three ways of phrasing
/// one. Which is right depends on how you work, so it is a setting rather than
/// a decision made for everyone.
///
/// Two candidates were deliberately left out. An AVERAGE across accounts
/// describes no account you could actually use — you work on one at a time, and
/// the mean of a full account and an empty one is a number matching neither.
/// TOTAL remaining capacity has the same defect and adds another: accounts sit
/// on different plans, so their percentages are not the same unit and summing
/// them is arithmetic on incomparable things.
public enum MenuBarMetric: String, Codable, Sendable, CaseIterable, Identifiable {
    /// "What is the status of the currently active account?" — 5h % and week %.
    case activeAccount
    /// "Is there somewhere fresh to work?" — the account you would switch to.
    case bestAccount
    /// "Is anything about to run out?" — the account closest to its limit.
    case worstAccount
    /// "How much runway is left across the fleet?" — how many accounts still
    /// have room.
    case accountsWithRoom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .activeAccount: "Active account"
        case .bestAccount: "Best account"
        case .worstAccount: "Busiest account"
        case .accountsWithRoom: "Accounts with room"
        }
    }

    public var explanation: String {
        switch self {
        case .activeAccount:
            "Remaining capacity of the active CLI account. The icon empties as quota is consumed."
        case .bestAccount:
            "Usage of the emptiest account. The icon empties as quota is used up."
        case .worstAccount:
            "Usage of the fullest account. The icon empties as it approaches the limit."
        case .accountsWithRoom:
            "How many accounts are still under \(Int(MenuBarReading.roomThreshold))%. The icon empties as accounts run out."
        }
    }
}
