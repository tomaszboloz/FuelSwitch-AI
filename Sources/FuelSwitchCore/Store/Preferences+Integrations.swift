import Foundation

extension Preferences {
    private static let statuslineEnabledKey = "statuslineEnabled"
    private static let adaptiveRefreshEnabledKey = "adaptiveRefreshEnabled"
    private static let usageHeatmapEnabledKey = "usageHeatmapEnabled"
    private static let sparkleAutoCheckEnabledKey = "sparkleAutoCheckEnabled"
    private static let sparkleAutoDownloadEnabledKey = "sparkleAutoDownloadEnabled"

    /// Opt-in: switching Codex also gracefully restarts the desktop app.
    public var codexDesktopSyncEnabled: Bool {
        get { defaults.bool(forKey: "codexDesktopSyncEnabled") }
        nonmutating set { defaults.set(newValue, forKey: "codexDesktopSyncEnabled") }
    }

    /// On by default: switching Gemini also swaps the Antigravity sign-in and
    /// restarts Antigravity.
    public var antigravitySyncEnabled: Bool {
        get { defaults.object(forKey: "antigravitySyncEnabled") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "antigravitySyncEnabled") }
    }

    /// Whether the active account's usage is written to the statusline cache.
    public var statuslineEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.statuslineEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.statuslineEnabledKey) }
    }

    /// Whether the poll interval is shortened automatically when CLI was active.
    public var adaptiveRefreshEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.adaptiveRefreshEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.adaptiveRefreshEnabledKey) }
    }

    /// Whether the Settings window shows the local Claude Code usage heatmap.
    public var usageHeatmapEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.usageHeatmapEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.usageHeatmapEnabledKey) }
    }

    /// Whether Sparkle checks for a new release in the background.
    public var sparkleAutoCheckEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.sparkleAutoCheckEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.sparkleAutoCheckEnabledKey) }
    }

    /// Whether Sparkle also downloads and installs a found update unattended.
    public var sparkleAutoDownloadEnabled: Bool {
        get {
            if let value = defaults.object(forKey: Self.sparkleAutoDownloadEnabledKey) as? Bool {
                return value
            }
            return false
        }
        nonmutating set { defaults.set(newValue, forKey: Self.sparkleAutoDownloadEnabledKey) }
    }
}
