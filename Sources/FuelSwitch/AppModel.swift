import SwiftUI
import AppKit
import Combine
import ServiceManagement
import FuelSwitchCore

@MainActor
final class AppModel: ObservableObject {
    var isPreview = false
    @Published var accounts: [Account] = []
    @Published var usage: [String: AccountUsage] = [:]
    @Published var isRefreshing = false
    @Published var resettingProviders: Set<Provider> = []
    @Published var resetResult: ResetResult?

    @Published var interfaceTemplate = Preferences().interfaceTemplate {
        didSet {
            guard !isPreview else { return }
            preferences.interfaceTemplate = interfaceTemplate
            FloatingWidgetController.shared.updateTemplate()
            if interfaceTemplate == .classic { NativeWindowController.shared.close() }
            else { NativeWindowController.shared.show(model: self) }
        }
    }

    @Published var activeClaudeEmail: String?
    @Published var activeCodexEmail: String?
    @Published var activeGeminiEmail: String?
    @Published var switchingProviders: Set<Provider> = []
    @Published var codexDesktopSyncEnabled = Preferences().codexDesktopSyncEnabled { didSet { preferences.codexDesktopSyncEnabled = codexDesktopSyncEnabled } }
    @Published var antigravitySyncEnabled = Preferences().antigravitySyncEnabled { didSet { preferences.antigravitySyncEnabled = antigravitySyncEnabled } }
    @Published var appTheme: String = Preferences().appTheme { didSet { if !isPreview { preferences.appTheme = appTheme; updateThemeAppearance() } } }
    @Published var widgetStyle: String = Preferences().widgetStyle { didSet { if !isPreview { preferences.widgetStyle = widgetStyle; FloatingWidgetController.shared.updateStyle() } } }
    @Published var showingSettings: Bool = false
    @Published var showsPercentInMenuBar = Preferences().showsPercentInMenuBar { didSet { preferences.showsPercentInMenuBar = showsPercentInMenuBar } }
    @Published var showFloatingWidget = Preferences().showFloatingWidget { didSet { preferences.showFloatingWidget = showFloatingWidget; FloatingWidgetController.shared.setVisible(showFloatingWidget) } }
    @Published var widgetOpacity: Double = Preferences().widgetOpacity { didSet { preferences.widgetOpacity = widgetOpacity; FloatingWidgetController.shared.updateOpacity(widgetOpacity) } }
    @Published var widgetAlwaysOnTop: Bool = Preferences().widgetAlwaysOnTop { didSet { preferences.widgetAlwaysOnTop = widgetAlwaysOnTop; FloatingWidgetController.shared.updateAlwaysOnTop(widgetAlwaysOnTop) } }
    @Published var menuBarMetric = Preferences().menuBarMetric { didSet { preferences.menuBarMetric = menuBarMetric } }
    @Published var menuBarIconStyle = Preferences().menuBarIconStyle { didSet { preferences.menuBarIconStyle = menuBarIconStyle } }
    @Published var notificationsEnabled = Preferences().notificationsEnabled { didSet { preferences.notificationsEnabled = notificationsEnabled; if notificationsEnabled { NotificationManager.requestAuthorizationIfNeeded() } } }
    @Published var notificationThresholds = Preferences().notificationThresholds { didSet { preferences.notificationThresholds = notificationThresholds } }
    @Published var notificationSoundEnabled = Preferences().notificationSoundEnabled { didSet { preferences.notificationSoundEnabled = notificationSoundEnabled } }
    @Published var autoSwitchEnabled = Preferences().autoSwitchEnabled { didSet { preferences.autoSwitchEnabled = autoSwitchEnabled } }
    @Published var paceEstimationEnabled = Preferences().paceEstimationEnabled { didSet { preferences.paceEstimationEnabled = paceEstimationEnabled } }
    @Published var statuslineEnabled = Preferences().statuslineEnabled { didSet { preferences.statuslineEnabled = statuslineEnabled } }
    @Published var adaptiveRefreshEnabled = Preferences().adaptiveRefreshEnabled { didSet { preferences.adaptiveRefreshEnabled = adaptiveRefreshEnabled } }
    @Published var usageHeatmapEnabled = Preferences().usageHeatmapEnabled { didSet { preferences.usageHeatmapEnabled = usageHeatmapEnabled; if usageHeatmapEnabled { loadUsageHeatmap() } } }
    @Published var usageHeatmapDays: [DailyTokenUsage] = []
    @Published var usageHeatmapIsLoading = false
    @Published var intervalSeconds: Double = Preferences().refreshIntervalSeconds {
        didSet {
            let target = Preferences.clampRefreshInterval(intervalSeconds)
            guard target == intervalSeconds else { intervalSeconds = target; return }
            preferences.refreshIntervalSeconds = intervalSeconds
        }
    }

    @Published var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @Published var launchAtLoginProblem: String?
    @Published var availableUpdate: AvailableUpdate?
    static let updateCheckInterval: TimeInterval = 6 * 3600
    var lastUpdateCheck: Date?
    @Published var isCheckingForUpdate = false
    @Published var justConfirmedUpToDate = false
    @Published var updateCheckFailed = false

    let sparkleUpdater = SparkleUpdateManager()
    @Published var sparkleAutoCheckEnabled = Preferences().sparkleAutoCheckEnabled {
        didSet {
            preferences.sparkleAutoCheckEnabled = sparkleAutoCheckEnabled
            sparkleUpdater.automaticallyChecksForUpdates = sparkleAutoCheckEnabled
            if !sparkleAutoCheckEnabled { sparkleAutoDownloadEnabled = false }
        }
    }
    @Published var sparkleAutoDownloadEnabled = Preferences().sparkleAutoDownloadEnabled {
        didSet {
            preferences.sparkleAutoDownloadEnabled = sparkleAutoDownloadEnabled
            sparkleUpdater.automaticallyDownloadsUpdates = sparkleAutoDownloadEnabled
        }
    }

    let preferences = Preferences()
    let store = AccountStore.default
    let poller: Poller
    let thresholdWatcher = ThresholdWatcher()
    let statuslineCaches: [Provider: StatuslineCache] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, StatuslineCache(provider: $0)) }
    )
    var loopTask: Task<Void, Never>?
    var lastManualSwitch: [Provider: Date] = [:]
    var lastAutoSwitch: [Provider: Date] = [:]
    static let manualSwitchGrace: TimeInterval = 120
    static let autoSwitchCooldown: TimeInterval = 300
    var loginTask: Task<Void, Never>?
    var autoDismissBannerTask: Task<Void, Never>?
    var activeAccountReloadRevision = 0
    var cancellables = Set<AnyCancellable>()
    let statuslineInstaller = StatuslineInstaller()
    @Published var isStatuslineInstalled = false
    @Published var loginState: LoginState = .idle
    @Published var antigravityLoginAccount: Account?

    init(preview: InterfaceTemplate? = nil, previewWidgetStyle: String = "expanded") {
        poller = Poller(
            store: store,
            providers: [
                .anthropic: AnthropicUsageClient(),
                .openai: CodexUsageClient(),
                .gemini: GeminiUsageClient(),
            ],
            oauth: [
                .anthropic: AnthropicOAuth(),
                .openai: OpenAIOAuth(),
                .gemini: GeminiOAuth(),
            ],
            codexAuthURL: CLISwitcher.codexAuthURL
        )
        if let preview {
            configurePreview(preview, style: previewWidgetStyle)
            return
        }
        configureStandardLaunch()
    }
}
