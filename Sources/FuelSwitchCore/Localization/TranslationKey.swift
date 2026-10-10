import Foundation

public enum TranslationKey: String, Sendable, CaseIterable {
    // General & Branding
    case appName = "app_name", interfaceTemplate = "interface_template"
    case templateClassic = "template_classic", templateNative = "template_native"
    case templateHelp = "template_help", openMainWindow = "open_main_window"
    case searchAccounts = "search_accounts", editNickname = "edit_nickname"
    case tagline = "tagline", ready = "ready", active = "active", standby = "standby"
    case switchTank = "switch_tank", engage = "engage", remove = "remove"
    case removeConfirm = "remove_confirm", cancel = "cancel", done = "done"
    case settings = "settings", quit = "quit", refresh = "refresh"
    case waitingTelemetry = "waiting_telemetry", noAccountsRegistered = "no_accounts_registered"

    // Cockpit Hero & Navigation
    case activeFuelTanks = "active_fuel_tanks", noActiveCliAccount = "no_active_cli_account"
    case allTanks = "all_tanks", allActiveTanks = "all_active_tanks"
    case addTank = "add_tank", addAccount = "add_account"
    case connectClaude = "connect_claude", connectCodex = "connect_codex", connectGemini = "connect_gemini"

    // HUD Widget
    case hudTitle = "hud_title", hudCompact = "hud_compact", hudExpanded = "hud_expanded"
    case hudAlwaysOnTop = "hud_always_on_top", hudOpacity = "hud_opacity", hudStyle = "hud_style"
    case hudToggle = "hud_toggle", hudOn = "hud_on", hudOff = "hud_off"
    case quickSwitch = "quick_switch", noProviderAccounts = "no_provider_accounts"

    // Settings
    case settingsAppearance = "settings_appearance", theme = "theme"
    case themeSystem = "theme_system", themeDark = "theme_dark", themeLight = "theme_light"
    case language = "language", selectLanguage = "select_language"
    case telemetryAutostart = "telemetry_autostart", checkQuotaEvery = "check_quota_every"
    case openAtLogin = "open_at_login", menuBarDisplay = "menu_bar_display"
    case showPercentInMenuBar = "show_percent_in_menu_bar", menuBarMetric = "menu_bar_metric"
    case securityTitle = "security_title", localCredentialsNotice = "local_credentials_notice", author = "author"

    // Metrics & Gauges
    case metricActive = "metric_active", metricBest = "metric_best"
    case metricBusiest = "metric_busiest", metricWithRoom = "metric_with_room"
    case fiveHourSession = "five_hour_session", weeklyQuota = "weekly_quota"
    case resetsIn = "resets_in", resetDone = "reset_done"
    case remainingFuel = "remaining_fuel", lowFuelWarning = "low_fuel_warning"
    case resetCreditsAvailable = "reset_credits_available", redeemResetCredit = "redeem_reset_credit"

    // Account Actions & Status
    case removeAccount = "remove_account", switchCliAccount = "switch_cli_account"
    case checkQuotaNow = "check_quota_now", resetLimit = "reset_limit", redeemResetHelp = "redeem_reset_help"
    case resetCompleted = "reset_completed", resetFailed = "reset_failed"
    case openClaudeReset = "open_claude_reset", claudeResetHelp = "claude_reset_help"
    case lowFuelWarningShort = "low_fuel_warning_short", accountsCount = "accounts_count"
    case versionLabel = "version_label", connecting = "connecting", versionAvailable = "version_available"
    case connected = "connected", reconnected = "reconnected", switched = "switched"
    case dismiss = "dismiss", download = "download", checkForUpdates = "check_for_updates"
    case checkingForUpdates = "checking_for_updates", upToDate = "up_to_date"
    case updateCheckFailed = "update_check_failed"

    // Provider Setup & Sessions
    case geminiSetupTitle = "gemini_setup_title", geminiSetupHelp = "gemini_setup_help"
    case geminiClientIdLabel = "gemini_client_id_label", geminiClientSecretLabel = "gemini_client_secret_label"
    case saveAndConnect = "save_and_connect", addClaude = "add_claude", addCodex = "add_codex", addGemini = "add_gemini"
    case connectMonitor = "connect_monitor", sessionExpired = "session_expired", reauthenticate = "reauthenticate"
    case awaitingCheck = "awaiting_check", cachedTelemetry = "cached_telemetry"
    case removeThisAccount = "remove_this_account", tanksCount = "tanks_count", removeCredit = "remove_credit"
    case telemetryInProgress = "telemetry_in_progress", toggleHudHelp = "toggle_hud_help"
    case addProviderAccount = "add_provider_account", operationFailed = "operation_failed"

    // App Integrations
    case codexDesktopSyncTitle = "codex_desktop_sync_title", codexDesktopSyncHelp = "codex_desktop_sync_help"
    case codexDesktopRestartFailed = "codex_desktop_restart_failed"
    case antigravitySyncTitle = "antigravity_sync_title", antigravitySyncHelp = "antigravity_sync_help"
    case antigravityRestartFailed = "antigravity_restart_failed"
    case antigravitySignInRequired = "antigravity_sign_in_required", antigravityAccountMismatch = "antigravity_account_mismatch"

    // Notifications & Auto-Switch
    case notificationsTitle = "notifications_title", notificationsToggle = "notifications_toggle"
    case notificationsSoundToggle = "notifications_sound_toggle", notificationThresholdsLabel = "notification_thresholds_label"
    case notificationThresholdTitle = "notification_threshold_title", notificationThresholdBody = "notification_threshold_body"
    case autoSwitchTitle = "auto_switch_title", autoSwitchToggle = "auto_switch_toggle"
    case autoSwitchExplanation = "auto_switch_explanation", autoSwitchedBanner = "auto_switched_banner"
    case autoSwitchNotificationTitle = "auto_switch_notification_title", autoSwitchNotificationBody = "auto_switch_notification_body"

    // Icons, Launchers, Heatmap, Updates
    case paceEstimationToggle = "pace_estimation_toggle", menuBarIconStyleLabel = "menu_bar_icon_style_label"
    case iconStyleGauge = "icon_style_gauge", iconStyleBattery = "icon_style_battery"
    case iconStylePercentOnly = "icon_style_percent_only", iconStyleMonochrome = "icon_style_monochrome"
    case launcherTitle = "launcher_title", launcherExplanation = "launcher_explanation"
    case copyShellSnippet = "copy_shell_snippet", shellSnippetCopied = "shell_snippet_copied"
    case statuslineTitle = "statusline_title", statuslineToggle = "statusline_toggle"
    case statuslineExplanation = "statusline_explanation", statuslineInstall = "statusline_install"
    case statuslineUninstall = "statusline_uninstall", adaptiveRefreshToggle = "adaptive_refresh_toggle"
    case usageHeatmapTitle = "usage_heatmap_title", usageHeatmapToggle = "usage_heatmap_toggle"
    case usageHeatmapExplanation = "usage_heatmap_explanation", usageHeatmapLoading = "usage_heatmap_loading"
    case usageHeatmapEmpty = "usage_heatmap_empty", usageHeatmapSummarySuffix = "usage_heatmap_summary_suffix"
    case sparkleUpdatesTitle = "sparkle_updates_title", sparkleAutoCheckToggle = "sparkle_auto_check_toggle"
    case sparkleAutoDownloadToggle = "sparkle_auto_download_toggle", sparkleExplanation = "sparkle_explanation"
}
