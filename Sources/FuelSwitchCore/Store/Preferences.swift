import Foundation

/// The two user settings, kept in `UserDefaults`. The keys were renamed along
/// with the app; every read reaches for the new key first and falls back to the
/// old one only when it is missing. That way correctness does NOT depend on the
/// order in which something reads these settings relative to `migrate()` —
/// unlike before, when `AppModel`'s property initialisers read the new keys
/// before `init()` had run the migration, so for a whole first session after
/// the rebrand the hard-coded defaults sat in memory (and `didSet` could
/// permanently overwrite correctly migrated data if the user touched the
/// toggle or the slider).
public struct Preferences {
    private let defaults: UserDefaults

    private static let showsPercentNewKey = "showPercentInMenuBar"
    private static let showsPercentOldKey = "pokazujProcent"
    private static let refreshIntervalNewKey = "refreshInterval"
    private static let refreshIntervalOldKey = "interwal"
    private static let menuBarMetricKey = "menuBarMetric"
    private static let menuBarIconStyleKey = "menuBarIconStyle"
    private static let dismissedUpdateKey = "dismissedUpdateVersion"
    private static let showFloatingWidgetKey = "showFloatingWidget"
    private static let widgetOpacityKey = "widgetOpacity"
    private static let widgetAlwaysOnTopKey = "widgetAlwaysOnTop"
    private static let widgetStyleKey = "widgetStyle"
    private static let appThemeKey = "appTheme"
    private static let notificationsEnabledKey = "notificationsEnabled"
    private static let notificationThresholdsKey = "notificationThresholds"
    private static let notificationSoundEnabledKey = "notificationSoundEnabled"
    private static let autoSwitchEnabledKey = "autoSwitchEnabled"
    private static let paceEstimationEnabledKey = "paceEstimationEnabled"
    private static let statuslineEnabledKey = "statuslineEnabled"
    private static let adaptiveRefreshEnabledKey = "adaptiveRefreshEnabled"
    private static let usageHeatmapEnabledKey = "usageHeatmapEnabled"
    private static let sparkleAutoCheckEnabledKey = "sparkleAutoCheckEnabled"
    private static let sparkleAutoDownloadEnabledKey = "sparkleAutoDownloadEnabled"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Upgrades and unrecognized future values preserve the original layout.
    public var interfaceTemplate: InterfaceTemplate {
        get { defaults.string(forKey: "interfaceTemplate").flatMap(InterfaceTemplate.init(rawValue:)) ?? .classic }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "interfaceTemplate") }
    }

    /// Opt-in: switching Codex also gracefully restarts the desktop app.
    public var codexDesktopSyncEnabled: Bool {
        get { defaults.bool(forKey: "codexDesktopSyncEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "codexDesktopSyncEnabled") }
    }

    /// Theme preference: "system", "dark", or "light"
    public var appTheme: String {
        get { defaults.string(forKey: Self.appThemeKey) ?? "system" }
        nonmutating set { defaults.set(newValue, forKey: Self.appThemeKey) }
    }

    /// Widget display style: "expanded" or "compact"
    public var widgetStyle: String {
        get { defaults.string(forKey: Self.widgetStyleKey) ?? "expanded" }
        nonmutating set { defaults.set(newValue, forKey: Self.widgetStyleKey) }
    }

    /// Whether the floating desktop HUD widget is displayed.
    public var showFloatingWidget: Bool {
        get { defaults.bool(forKey: Self.showFloatingWidgetKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.showFloatingWidgetKey) }
    }

    /// Opacity of the floating widget background (0.3 to 1.0).
    public var widgetOpacity: Double {
        get {
            if let value = defaults.object(forKey: Self.widgetOpacityKey) as? Double {
                return min(max(value, 0.3), 1.0)
            }
            return 0.90
        }
        nonmutating set {
            let clamped = min(max(newValue, 0.3), 1.0)
            defaults.set(clamped, forKey: Self.widgetOpacityKey)
        }
    }

    /// Whether the floating widget stays on top of all application windows.
    public var widgetAlwaysOnTop: Bool {
        get {
            if let value = defaults.object(forKey: Self.widgetAlwaysOnTopKey) as? Bool {
                return value
            }
            return true
        }
        nonmutating set { defaults.set(newValue, forKey: Self.widgetAlwaysOnTopKey) }
    }

    public var showsPercentInMenuBar: Bool {
        get {
            if let value = defaults.object(forKey: Self.showsPercentNewKey) as? Bool {
                return value
            }
            return defaults.object(forKey: Self.showsPercentOldKey) as? Bool ?? true
        }
        nonmutating set { defaults.set(newValue, forKey: Self.showsPercentNewKey) }
    }

    /// What the menu bar's number answers. An unrecognised stored value falls
    /// back to the default rather than failing — the set of metrics may grow or
    /// shrink between versions.
    public var menuBarMetric: MenuBarMetric {
        get {
            (defaults.string(forKey: Self.menuBarMetricKey)).flatMap(MenuBarMetric.init(rawValue:))
                ?? .activeAccount
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.menuBarMetricKey) }
    }

    /// How the menu bar glyph is drawn. An unrecognised stored value falls
    /// back to the default rather than failing.
    public var menuBarIconStyle: MenuBarIconStyle {
        get {
            (defaults.string(forKey: Self.menuBarIconStyleKey)).flatMap(MenuBarIconStyle.init(rawValue:))
                ?? .gauge
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.menuBarIconStyleKey) }
    }

    /// Whether threshold usage notifications are turned on. Off by default —
    /// a new feature that reaches outside the app (posting to Notification
    /// Center) should not surprise anyone who upgrades.
    public var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Self.notificationsEnabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.notificationsEnabledKey) }
    }

    /// The usage percentages that trigger a notification. Stored as `[Int]`
    /// directly — `UserDefaults` supports array-of-number natively, no
    /// encoding needed.
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

    /// Whether the app may switch the active CLI account on its own when
    /// the active one runs dry. Off by default — this rewrites CLI
    /// credential files unattended, so it is opt-in even though the
    /// underlying `CLISwitcher.switch(to:)` call is the same one the
    /// "Engage" button already uses.
    public var autoSwitchEnabled: Bool {
        get { defaults.bool(forKey: Self.autoSwitchEnabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.autoSwitchEnabledKey) }
    }

    /// Whether the pace glyph (ahead / on pace / burning fast) is shown next
    /// to usage percentages. Purely visual, no side effect on credentials,
    /// so it defaults on — but still gets a toggle for anyone who finds it noisy.
    public var paceEstimationEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.paceEstimationEnabledKey) as? Bool {
                return value
            }
            return true
        }
        nonmutating set { defaults.set(newValue, forKey: Self.paceEstimationEnabledKey) }
    }

    /// Whether the active account's usage is written to the statusline cache
    /// after every poll, for the generated Claude Code statusline script to
    /// read. Off by default — it's an opt-in integration, not a display tweak.
    public var statuslineEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.statuslineEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.statuslineEnabledKey) }
    }

    /// Whether the poll interval is shortened automatically when the CLI was
    /// used recently. Opt-in, layered on top of the manual interval slider
    /// rather than replacing it.
    public var adaptiveRefreshEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.adaptiveRefreshEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.adaptiveRefreshEnabledKey) }
    }

    /// Whether the Settings window shows the local Claude Code usage heatmap,
    /// parsed from `~/.claude/projects/**/*.jsonl` on disk. Off by default —
    /// parsing every transcript file is real disk I/O, not a free display toggle.
    public var usageHeatmapEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.usageHeatmapEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.usageHeatmapEnabledKey) }
    }

    /// Whether Sparkle checks for a new release in the background, on its own
    /// schedule, instead of only when the user presses "Check for Updates".
    /// Off by default — same opt-in convention as every other side-effecting
    /// feature here.
    public var sparkleAutoCheckEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.sparkleAutoCheckEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.sparkleAutoCheckEnabledKey) }
    }

    /// Whether Sparkle also downloads and installs a found update unattended,
    /// rather than just notifying. Only meaningful alongside
    /// `sparkleAutoCheckEnabled`; kept as its own switch because unattended
    /// install is the riskier half.
    public var sparkleAutoDownloadEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.sparkleAutoDownloadEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.sparkleAutoDownloadEnabledKey) }
    }

    /// The version whose update notice was dismissed. Storing the version
    /// rather than a flag means the next release speaks up again, while the one
    /// already waved away stays quiet.
    public var dismissedUpdateVersion: String? {
        get { defaults.string(forKey: Self.dismissedUpdateKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.dismissedUpdateKey) }
    }

    /// The slider in Settings is limited to 60...1800, and the same clamp
    /// applies here again on both read AND write — otherwise an older value
    /// written by an earlier version of the app could fall below the threshold
    /// at which Anthropic hard-rejects requests (429 per account).
    public var refreshIntervalSeconds: Double {
        get {
            let stored = (defaults.object(forKey: Self.refreshIntervalNewKey) as? Double)
                ?? (defaults.object(forKey: Self.refreshIntervalOldKey) as? Double)
                ?? Poller.baseInterval
            return Self.clampRefreshInterval(stored)
        }
        nonmutating set { defaults.set(Self.clampRefreshInterval(newValue), forKey: Self.refreshIntervalNewKey) }
    }

    /// The lower bound is Anthropic's hard threshold (`Poller.minimumInterval`);
    /// the upper one is the range of the slider in Settings. Public so that a
    /// caller such as `AppModel` can check whether a value will be clamped
    /// before storing it, without duplicating the same bounds.
    public static func clampRefreshInterval(_ value: Double) -> Double {
        min(max(value, Poller.minimumInterval), 1800)
    }

    /// Copies the old keys to the new ones and removes the old. With the
    /// fallback in place on read this is only housekeeping, not a condition for
    /// correctness — safe to call repeatedly, since later runs have nothing
    /// left to move.
    public func migrate() {
        for (old, new) in [(Self.showsPercentOldKey, Self.showsPercentNewKey),
                            (Self.refreshIntervalOldKey, Self.refreshIntervalNewKey)] {
            guard defaults.object(forKey: new) == nil, let value = defaults.object(forKey: old) else { continue }
            defaults.set(value, forKey: new)
            defaults.removeObject(forKey: old)
        }
    }
}
