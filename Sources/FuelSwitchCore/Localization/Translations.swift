import Foundation

public enum TranslationKey: String, Sendable, CaseIterable {
    // General & Branding
    case appName = "app_name"
    case interfaceTemplate = "interface_template"
    case templateClassic = "template_classic"
    case templateNative = "template_native"
    case templateHelp = "template_help"
    case openMainWindow = "open_main_window"
    case searchAccounts = "search_accounts"
    case editNickname = "edit_nickname"
    case tagline = "tagline"
    case ready = "ready"
    case active = "active"
    case standby = "standby"
    case switchTank = "switch_tank"
    case engage = "engage"
    case remove = "remove"
    case removeConfirm = "remove_confirm"
    case cancel = "cancel"
    case done = "done"
    case settings = "settings"
    case quit = "quit"
    case refresh = "refresh"
    case waitingTelemetry = "waiting_telemetry"
    case noAccountsRegistered = "no_accounts_registered"

    // Cockpit Hero & Navigation
    case activeFuelTanks = "active_fuel_tanks"
    case noActiveCliAccount = "no_active_cli_account"
    case allTanks = "all_tanks"
    case allActiveTanks = "all_active_tanks"
    case addTank = "add_tank"
    case addAccount = "add_account"
    case connectClaude = "connect_claude"
    case connectCodex = "connect_codex"
    case connectGemini = "connect_gemini"

    // HUD Widget
    case hudTitle = "hud_title"
    case hudCompact = "hud_compact"
    case hudExpanded = "hud_expanded"
    case hudAlwaysOnTop = "hud_always_on_top"
    case hudOpacity = "hud_opacity"
    case hudStyle = "hud_style"
    case hudToggle = "hud_toggle"
    case hudOn = "hud_on"
    case hudOff = "hud_off"
    case quickSwitch = "quick_switch"
    case noProviderAccounts = "no_provider_accounts"

    // Settings
    case settingsAppearance = "settings_appearance"
    case theme = "theme"
    case themeSystem = "theme_system"
    case themeDark = "theme_dark"
    case themeLight = "theme_light"
    case language = "language"
    case selectLanguage = "select_language"
    case telemetryAutostart = "telemetry_autostart"
    case checkQuotaEvery = "check_quota_every"
    case openAtLogin = "open_at_login"
    case menuBarDisplay = "menu_bar_display"
    case showPercentInMenuBar = "show_percent_in_menu_bar"
    case menuBarMetric = "menu_bar_metric"
    case securityTitle = "security_title"
    case localCredentialsNotice = "local_credentials_notice"
    case author = "author"

    // Metrics
    case metricActive = "metric_active"
    case metricBest = "metric_best"
    case metricBusiest = "metric_busiest"
    case metricWithRoom = "metric_with_room"

    // Gauges & Times
    case fiveHourSession = "five_hour_session"
    case weeklyQuota = "weekly_quota"
    case resetsIn = "resets_in"
    case resetDone = "reset_done"
    case remainingFuel = "remaining_fuel"
    case lowFuelWarning = "low_fuel_warning"
    case resetCreditsAvailable = "reset_credits_available"
    case redeemResetCredit = "redeem_reset_credit"

    // New keys for hardcoded strings
    case removeAccount = "remove_account"
    case switchCliAccount = "switch_cli_account"
    case checkQuotaNow = "check_quota_now"
    case resetLimit = "reset_limit"
    case redeemResetHelp = "redeem_reset_help"
    case lowFuelWarningShort = "low_fuel_warning_short"
    case accountsCount = "accounts_count"
    case versionLabel = "version_label"
    case connecting = "connecting"
    case versionAvailable = "version_available"
    case connected = "connected"
    case reconnected = "reconnected"
    case switched = "switched"
    case dismiss = "dismiss"
    case download = "download"
    case checkForUpdates = "check_for_updates"
    case checkingForUpdates = "checking_for_updates"
    case upToDate = "up_to_date"
    case updateCheckFailed = "update_check_failed"
    case geminiSetupTitle = "gemini_setup_title"
    case geminiSetupHelp = "gemini_setup_help"
    case geminiClientIdLabel = "gemini_client_id_label"
    case geminiClientSecretLabel = "gemini_client_secret_label"
    case saveAndConnect = "save_and_connect"
    case addClaude = "add_claude"
    case addCodex = "add_codex"
    case addGemini = "add_gemini"
    case connectMonitor = "connect_monitor"
    case sessionExpired = "session_expired"
    case awaitingCheck = "awaiting_check"
    case cachedTelemetry = "cached_telemetry"
    case removeThisAccount = "remove_this_account"
    case tanksCount = "tanks_count"
    case removeCredit = "remove_credit"
    case telemetryInProgress = "telemetry_in_progress"
    case toggleHudHelp = "toggle_hud_help"
    case addProviderAccount = "add_provider_account"
    case operationFailed = "operation_failed"
    case codexDesktopSyncTitle = "codex_desktop_sync_title"
    case codexDesktopSyncHelp = "codex_desktop_sync_help"
    case codexDesktopRestartFailed = "codex_desktop_restart_failed"

    // Notifications & Auto-Switch
    case notificationsTitle = "notifications_title"
    case notificationsToggle = "notifications_toggle"
    case notificationsSoundToggle = "notifications_sound_toggle"
    case notificationThresholdsLabel = "notification_thresholds_label"
    case notificationThresholdTitle = "notification_threshold_title"
    case notificationThresholdBody = "notification_threshold_body"
    case autoSwitchTitle = "auto_switch_title"
    case autoSwitchToggle = "auto_switch_toggle"
    case autoSwitchExplanation = "auto_switch_explanation"
    case autoSwitchedBanner = "auto_switched_banner"
    case autoSwitchNotificationTitle = "auto_switch_notification_title"
    case autoSwitchNotificationBody = "auto_switch_notification_body"

    // Pace Estimation
    case paceEstimationToggle = "pace_estimation_toggle"

    // Menu Bar Icon Style
    case menuBarIconStyleLabel = "menu_bar_icon_style_label"
    case iconStyleGauge = "icon_style_gauge"
    case iconStyleBattery = "icon_style_battery"
    case iconStylePercentOnly = "icon_style_percent_only"
    case iconStyleMonochrome = "icon_style_monochrome"

    // Per-Profile Launcher
    case launcherTitle = "launcher_title"
    case launcherExplanation = "launcher_explanation"
    case copyShellSnippet = "copy_shell_snippet"
    case shellSnippetCopied = "shell_snippet_copied"

    // Claude Code Statusline
    case statuslineTitle = "statusline_title"
    case statuslineToggle = "statusline_toggle"
    case statuslineExplanation = "statusline_explanation"
    case statuslineInstall = "statusline_install"
    case statuslineUninstall = "statusline_uninstall"

    // Adaptive Refresh
    case adaptiveRefreshToggle = "adaptive_refresh_toggle"

    // Usage Heatmap
    case usageHeatmapTitle = "usage_heatmap_title"
    case usageHeatmapToggle = "usage_heatmap_toggle"
    case usageHeatmapExplanation = "usage_heatmap_explanation"
    case usageHeatmapLoading = "usage_heatmap_loading"
    case usageHeatmapEmpty = "usage_heatmap_empty"
    case usageHeatmapSummarySuffix = "usage_heatmap_summary_suffix"

    // Sparkle Automatic Updates
    case sparkleUpdatesTitle = "sparkle_updates_title"
    case sparkleAutoCheckToggle = "sparkle_auto_check_toggle"
    case sparkleAutoDownloadToggle = "sparkle_auto_download_toggle"
    case sparkleExplanation = "sparkle_explanation"
}

public struct Translations {
    public static func lookup(_ key: TranslationKey, in language: AppLanguage) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    /// Used by the test suite to make a missing entry a release-blocking error
    /// instead of quietly falling back to English.
    static func missingKeys(in language: AppLanguage) -> [TranslationKey] {
        TranslationKey.allCases.filter { table[language]?[$0]?.isEmpty ?? true }
    }

    private static let table: [AppLanguage: [TranslationKey: String]] = [
        .english: englishTable,
        .polish: polishTable,
        .spanish: spanishTable,
        .german: germanTable,
        .french: frenchTable,
        .japanese: japaneseTable,
        .chinese: chineseTable,
        .portuguese: portugueseTable,
        .russian: russianTable,
        .korean: koreanTable,
        .hindi: hindiTable,
        .arabic: arabicTable,
    ]
}
