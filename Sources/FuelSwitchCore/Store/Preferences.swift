import Foundation

/// User settings kept in `UserDefaults`.
public struct Preferences {
    let defaults: UserDefaults

    private static let showsPercentNewKey = "showPercentInMenuBar"
    private static let showsPercentOldKey = "pokazujProcent"
    private static let refreshIntervalNewKey = "refreshInterval"
    private static let refreshIntervalOldKey = "interwal"
    private static let menuBarMetricKey = "menuBarMetric"
    private static let menuBarIconStyleKey = "menuBarIconStyle"
    private static let dismissedUpdateKey = "dismissedUpdateVersion"
    private static let appThemeKey = "appTheme"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Upgrades and unrecognized future values preserve the original layout.
    public var interfaceTemplate: InterfaceTemplate {
        get { defaults.string(forKey: "interfaceTemplate").flatMap(InterfaceTemplate.init(rawValue:)) ?? .classic }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "interfaceTemplate") }
    }

    /// Theme preference: "system", "dark", or "light"
    public var appTheme: String {
        get { defaults.string(forKey: Self.appThemeKey) ?? "system" }
        nonmutating set { defaults.set(newValue, forKey: Self.appThemeKey) }
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

    /// What the menu bar's number answers.
    public var menuBarMetric: MenuBarMetric {
        get {
            (defaults.string(forKey: Self.menuBarMetricKey)).flatMap(MenuBarMetric.init(rawValue:))
                ?? .activeAccount
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.menuBarMetricKey) }
    }

    /// How the menu bar glyph is drawn.
    public var menuBarIconStyle: MenuBarIconStyle {
        get {
            (defaults.string(forKey: Self.menuBarIconStyleKey)).flatMap(MenuBarIconStyle.init(rawValue:))
                ?? .gauge
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.menuBarIconStyleKey) }
    }

    /// The version whose update notice was dismissed.
    public var dismissedUpdateVersion: String? {
        get { defaults.string(forKey: Self.dismissedUpdateKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.dismissedUpdateKey) }
    }

    /// Clamped refresh interval in seconds.
    public var refreshIntervalSeconds: Double {
        get {
            let stored = (defaults.object(forKey: Self.refreshIntervalNewKey) as? Double)
                ?? (defaults.object(forKey: Self.refreshIntervalOldKey) as? Double)
                ?? Poller.baseInterval
            return Self.clampRefreshInterval(stored)
        }
        nonmutating set { defaults.set(Self.clampRefreshInterval(newValue), forKey: Self.refreshIntervalNewKey) }
    }

    public static func clampRefreshInterval(_ value: Double) -> Double {
        min(max(value, Poller.minimumInterval), 1800)
    }

    /// Copies old keys to new ones and removes old keys.
    public func migrate() {
        for (old, new) in [(Self.showsPercentOldKey, Self.showsPercentNewKey),
                            (Self.refreshIntervalOldKey, Self.refreshIntervalNewKey)] {
            guard defaults.object(forKey: new) == nil, let value = defaults.object(forKey: old) else { continue }
            defaults.set(value, forKey: new)
            defaults.removeObject(forKey: old)
        }
    }
}
