import Foundation

extension Preferences {
    private static let notificationsEnabledKey = "notificationsEnabled"
    private static let notificationThresholdsKey = "notificationThresholds"
    private static let notificationSoundEnabledKey = "notificationSoundEnabled"
    private static let autoSwitchEnabledKey = "autoSwitchEnabled"
    private static let paceEstimationEnabledKey = "paceEstimationEnabled"

    /// Whether threshold usage notifications are turned on.
    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Self.notificationsEnabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.notificationsEnabledKey) }
    }

    /// The usage percentages that trigger a notification.
    public var notificationThresholds: [Int] {
        get { (defaults.array(forKey: Self.notificationThresholdsKey) as? [Int]) ?? [75, 90, 95] }
        nonmutating set { defaults.set(newValue, forKey: Self.notificationThresholdsKey) }
    }

    /// Whether a threshold notification plays the system sound.
    public var notificationSoundEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.notificationSoundEnabledKey) as? Bool {
                return value
            }
            return true
        }
        nonmutating set { defaults.set(newValue, forKey: Self.notificationSoundEnabledKey) }
    }

    /// Whether the app may switch the active CLI account automatically.
    public var autoSwitchEnabled: Bool {
        get { defaults.bool(forKey: Self.autoSwitchEnabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.autoSwitchEnabledKey) }
    }

    /// Whether the pace glyph is shown next to usage percentages.
    public var paceEstimationEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.paceEstimationEnabledKey) as? Bool {
                return value
            }
            return true
        }
        nonmutating set { defaults.set(newValue, forKey: Self.paceEstimationEnabledKey) }
    }
}
