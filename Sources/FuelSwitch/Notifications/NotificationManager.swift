import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter`. Kept out of `FuelSwitchCore`
/// deliberately — it is AppKit-adjacent glue with no logic worth testing, the
/// same rationale that keeps `MenuBarIcon`'s drawing code untested. All the
/// decisions about WHETHER and WHEN to notify live in `ThresholdWatcher` and
/// `AutoSwitchDecider`; this only turns an already-made decision into a
/// system notification.
@MainActor
enum NotificationManager {
    /// Requests permission once. Safe to call on every launch — the system
    /// only prompts the first time, and silently no-ops afterward whether
    /// the user granted or denied it.
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Posts a threshold-crossing notification. `identifier` is stable per
    /// `(account, window)` so a rapid re-fire replaces the existing banner
    /// instead of stacking a second one in Notification Center.
    static func postThresholdNotification(
        accountId: String,
        windowLabel: String,
        title: String,
        body: String,
        soundEnabled: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if soundEnabled { content.sound = .default }
        let identifier = "threshold|\(accountId)|\(windowLabel)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Posts a one-off notification for an automatic account switch.
    static func postAutoSwitchNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
