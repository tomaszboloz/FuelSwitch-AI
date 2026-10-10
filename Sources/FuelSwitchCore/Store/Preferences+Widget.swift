import Foundation

extension Preferences {
    private static let showFloatingWidgetKey = "showFloatingWidget"
    private static let widgetOpacityKey = "widgetOpacity"
    private static let widgetAlwaysOnTopKey = "widgetAlwaysOnTop"
    private static let widgetStyleKey = "widgetStyle"

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
}
