import SwiftUI
import AppKit
import Combine
import ServiceManagement
import FuelSwitchCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var usage: [String: AccountUsage] = [:]
    @Published private(set) var isRefreshing = false

    /// Currently active account emails in the CLI config files.
    @Published private(set) var activeClaudeEmail: String?
    @Published private(set) var activeCodexEmail: String?
    @Published private(set) var activeGeminiEmail: String?
    @Published private(set) var switchingProviders: Set<Provider> = []
    @Published var codexDesktopSyncEnabled = Preferences().codexDesktopSyncEnabled {
        didSet { preferences.codexDesktopSyncEnabled = codexDesktopSyncEnabled }
    }

    /// Theme preference: "system", "dark", or "light"
    @Published var appTheme: String = Preferences().appTheme {
        didSet {
            preferences.appTheme = appTheme
            updateThemeAppearance()
        }
    }

    /// ColorScheme resolved from appTheme
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Widget display style: "expanded" or "compact"
    @Published var widgetStyle: String = Preferences().widgetStyle {
        didSet {
            preferences.widgetStyle = widgetStyle
            FloatingWidgetController.shared.updateStyle()
        }
    }

    /// Whether the Settings screen is being shown in the menu panel
    @Published var showingSettings: Bool = false

    /// Localization manager reference
    var localization: LocalizationManager {
        LocalizationManager.shared
    }

    func t(_ key: TranslationKey) -> String {
        localization.text(key)
    }

    private func updateThemeAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.appTheme {
            case "dark":
                NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApplication.shared.appearance = NSAppearance(named: .aqua)
            default:
                NSApplication.shared.appearance = nil
            }
        }
    }

    /// The initial value reads `Preferences()` directly (not through
    /// `self.preferences`, because `self` does not exist yet in a property
    /// initialiser) — but that does not matter: the read falls back to the old
    /// key on its own when the new one is missing, so correctness does not
    /// depend on whether `preferences.migrate()` in `init()` has run yet.
    @Published var showsPercentInMenuBar = Preferences().showsPercentInMenuBar {
        didSet { preferences.showsPercentInMenuBar = showsPercentInMenuBar }
    }

    /// Whether the floating desktop widget HUD is active.
    @Published var showFloatingWidget = Preferences().showFloatingWidget {
        didSet {
            preferences.showFloatingWidget = showFloatingWidget
            FloatingWidgetController.shared.setVisible(showFloatingWidget)
        }
    }

    /// Transparency / opacity of the desktop HUD.
    @Published var widgetOpacity: Double = Preferences().widgetOpacity {
        didSet {
            preferences.widgetOpacity = widgetOpacity
            FloatingWidgetController.shared.updateOpacity(widgetOpacity)
        }
    }

    /// Whether the desktop HUD floats on top of other windows.
    @Published var widgetAlwaysOnTop: Bool = Preferences().widgetAlwaysOnTop {
        didSet {
            preferences.widgetAlwaysOnTop = widgetAlwaysOnTop
            FloatingWidgetController.shared.updateAlwaysOnTop(widgetAlwaysOnTop)
        }
    }

    /// Which question the menu bar answers. See `MenuBarMetric`.
    @Published var menuBarMetric = Preferences().menuBarMetric {
        didSet { preferences.menuBarMetric = menuBarMetric }
    }

    /// How the menu bar glyph is drawn. See `MenuBarIconStyle`.
    @Published var menuBarIconStyle = Preferences().menuBarIconStyle {
        didSet { preferences.menuBarIconStyle = menuBarIconStyle }
    }

    /// Whether threshold usage notifications are on. Off by default.
    @Published var notificationsEnabled = Preferences().notificationsEnabled {
        didSet {
            preferences.notificationsEnabled = notificationsEnabled
            if notificationsEnabled { NotificationManager.requestAuthorizationIfNeeded() }
        }
    }

    /// The usage percentages that trigger a notification.
    @Published var notificationThresholds = Preferences().notificationThresholds {
        didSet { preferences.notificationThresholds = notificationThresholds }
    }

    /// Whether a threshold notification plays the system sound.
    @Published var notificationSoundEnabled = Preferences().notificationSoundEnabled {
        didSet { preferences.notificationSoundEnabled = notificationSoundEnabled }
    }

    /// Whether the app may switch the active CLI account on its own when it
    /// runs dry. Off by default, since it rewrites CLI credential files
    /// unattended — see `Preferences.autoSwitchEnabled`.
    @Published var autoSwitchEnabled = Preferences().autoSwitchEnabled {
        didSet { preferences.autoSwitchEnabled = autoSwitchEnabled }
    }

    /// Whether the pace glyph (ahead / on pace / burning fast) is shown next
    /// to usage percentages. Purely visual — on by default.
    @Published var paceEstimationEnabled = Preferences().paceEstimationEnabled {
        didSet { preferences.paceEstimationEnabled = paceEstimationEnabled }
    }

    /// Whether the active Claude account's usage is written to the
    /// statusline cache after every poll. Off by default — see
    /// `Preferences.statuslineEnabled`.
    @Published var statuslineEnabled = Preferences().statuslineEnabled {
        didSet { preferences.statuslineEnabled = statuslineEnabled }
    }

    /// Whether the poll interval shortens automatically after recent CLI
    /// activity. See `Preferences.adaptiveRefreshEnabled`.
    @Published var adaptiveRefreshEnabled = Preferences().adaptiveRefreshEnabled {
        didSet { preferences.adaptiveRefreshEnabled = adaptiveRefreshEnabled }
    }

    /// Whether Settings shows the local Claude Code usage heatmap. See
    /// `Preferences.usageHeatmapEnabled`.
    @Published var usageHeatmapEnabled = Preferences().usageHeatmapEnabled {
        didSet {
            preferences.usageHeatmapEnabled = usageHeatmapEnabled
            if usageHeatmapEnabled { loadUsageHeatmap() }
        }
    }

    @Published private(set) var usageHeatmapDays: [DailyTokenUsage] = []
    @Published private(set) var usageHeatmapIsLoading = false

    /// Parses `~/.claude/projects/**/*.jsonl` off the main thread and
    /// publishes a zero-filled 90-day rollup. Safe to call repeatedly — a
    /// run already in flight just gets superseded by the next one's result.
    func loadUsageHeatmap() {
        guard usageHeatmapEnabled else { return }
        usageHeatmapIsLoading = true
        Task.detached(priority: .utility) {
            let entries = ClaudeProjectLogParser.parseAllProjects()
            let days = ClaudeUsageRollup.lastDays(90, from: entries)
            await MainActor.run {
                self.usageHeatmapDays = days
                self.usageHeatmapIsLoading = false
            }
        }
    }

    /// Toggles one threshold in and out of `notificationThresholds` — the
    /// checkbox binding in Settings.
    func toggleNotificationThreshold(_ threshold: Int) {
        if notificationThresholds.contains(threshold) {
            notificationThresholds.removeAll { $0 == threshold }
        } else {
            notificationThresholds.append(threshold)
        }
    }

    /// The slider in Settings is limited to 60...1800; `Preferences` clamps to
    /// the same bounds on read and write, so here we merely mirror the result
    /// of that clamp into `intervalSeconds` rather than computing it twice.
    @Published var intervalSeconds: Double = Preferences().refreshIntervalSeconds {
        didSet {
            let target = Preferences.clampRefreshInterval(intervalSeconds)
            guard target == intervalSeconds else {
                intervalSeconds = target
                return
            }
            preferences.refreshIntervalSeconds = intervalSeconds
        }
    }

    /// Whether macOS starts the app at login. The real state lives in the
    /// system, not here, so this mirrors it and is re-read after every change
    /// rather than assumed: registration can fail, and it can also land in
    /// `.requiresApproval` when the user has switched the item off in System
    /// Settings, which is not a failure but is not "on" either.
    @Published private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled
    /// Set when the system refused the last change, so the panel can say so
    /// instead of quietly flipping the switch back.
    @Published private(set) var launchAtLoginProblem: String?

    func setLaunchAtLogin(_ wanted: Bool) {
        do {
            if wanted {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginProblem = nil
        } catch {
            launchAtLoginProblem = wanted
                ? "macOS refused to add this as a login item. Check Login Items in System Settings."
                : "macOS refused to remove this login item. Check Login Items in System Settings."
        }
        // Trust the system over what we asked for.
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        if launchesAtLogin != wanted, launchAtLoginProblem == nil {
            launchAtLoginProblem = SMAppService.mainApp.status == .requiresApproval
                ? "Waiting for approval in System Settings, under Login Items."
                : nil
        }
    }

    /// A newer release, once one is found and while it has not been waved away.
    @Published private(set) var availableUpdate: AvailableUpdate?

    /// What this build calls itself, which is what any newer version is
    /// compared against.
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func dismissUpdate() {
        preferences.dismissedUpdateVersion = availableUpdate?.version
        availableUpdate = nil
    }

    func openUpdate() {
        sparkleUpdater.checkForUpdates()
    }

    /// Poll the installable feed at launch and every six hours. A failed
    /// background check is silent and does not claim the app is current.
    private static let updateCheckInterval: TimeInterval = 6 * 3600
    private var lastUpdateCheck: Date?
    @Published private(set) var isCheckingForUpdate = false
    /// Set only by a manual check, so a silent background poll never pops an
    /// "up to date" message the user did not ask for.
    @Published private(set) var justConfirmedUpToDate = false
    @Published private(set) var updateCheckFailed = false

    private func checkForUpdateIfDue() async {
        let now = Date()
        if let last = lastUpdateCheck, now.timeIntervalSince(last) < Self.updateCheckInterval {
            return
        }
        lastUpdateCheck = now
        guard let found = try? await UpdateChecker().check(currentVersion: currentVersion) else { return }
        guard preferences.dismissedUpdateVersion != found.version else { return }
        availableUpdate = found
    }

    /// Bypasses the six-hour throttle so a user pressing "Check for Updates"
    /// gets an answer right away.
    func checkForUpdateNow() {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        justConfirmedUpToDate = false
        updateCheckFailed = false
        availableUpdate = nil
        Task {
            defer { isCheckingForUpdate = false }
            lastUpdateCheck = Date()
            do {
                guard let found = try await UpdateChecker().check(currentVersion: currentVersion) else {
                    justConfirmedUpToDate = true
                    return
                }
                preferences.dismissedUpdateVersion = nil
                availableUpdate = found
                sparkleUpdater.checkForUpdates()
            } catch {
                updateCheckFailed = true
            }
        }
    }

    /// Opt-in unattended path: Sparkle downloads, verifies (EdDSA), and
    /// installs a newer release in the background. Off by default, same as
    /// every other side-effecting feature in this app.
    private let sparkleUpdater = SparkleUpdateManager()

    @Published var sparkleAutoCheckEnabled = Preferences().sparkleAutoCheckEnabled {
        didSet {
            preferences.sparkleAutoCheckEnabled = sparkleAutoCheckEnabled
            sparkleUpdater.automaticallyChecksForUpdates = sparkleAutoCheckEnabled
            if !sparkleAutoCheckEnabled {
                sparkleAutoDownloadEnabled = false
            }
        }
    }

    @Published var sparkleAutoDownloadEnabled = Preferences().sparkleAutoDownloadEnabled {
        didSet {
            preferences.sparkleAutoDownloadEnabled = sparkleAutoDownloadEnabled
            sparkleUpdater.automaticallyDownloadsUpdates = sparkleAutoDownloadEnabled
        }
    }

    /// Opens Sparkle's own update window regardless of the automatic-check
    /// toggle above — lets a user pull a real install without waiting.
    func checkForSparkleUpdateNow() {
        checkForUpdateNow()
    }

    private let preferences = Preferences()
    private let store = AccountStore.default
    private let poller: Poller
    private let thresholdWatcher = ThresholdWatcher()
    private let statuslineCaches: [Provider: StatuslineCache] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.map { ($0, StatuslineCache(provider: $0)) }
    )
    private var loopTask: Task<Void, Never>?
    /// Anti-flapping state for auto-switch, keyed by provider. A manual
    /// switch always wins for `manualSwitchGrace` after it happens; an
    /// automatic switch will not repeat for the same provider within
    /// `autoSwitchCooldown` — comfortably longer than the 60-second poll
    /// floor, so a provider does not bounce between two accounts every
    /// cycle.
    private var lastManualSwitch: [Provider: Date] = [:]
    private var lastAutoSwitch: [Provider: Date] = [:]
    private static let manualSwitchGrace: TimeInterval = 120
    private static let autoSwitchCooldown: TimeInterval = 300
    /// A handle on the sign-in currently in progress. Kept here rather than in
    /// the view so that "Cancel" and closing the window can genuinely interrupt
    /// it: `LoginFlow.logIn` responds to cancellation of this task by releasing
    /// the `CallbackListener` (see `LoginFlow.awaitCodeWithTimeout`), instead
    /// of merely hiding the window and leaving the listener — and, for Codex,
    /// port 1455 — occupied for the life of the process.
    private var loginTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init() {
        for legacyDir in AccountStore.legacyDirectories {
            _ = try? StoreMigration.run(
                from: legacyDir,
                to: AccountStore.defaultDirectory
            )
        }
        preferences.migrate()
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
        loadAccounts()
        startLoop()
        updateThemeAppearance()
        FloatingWidgetController.shared.configure(with: self)
        isStatuslineInstalled = statuslineInstaller.isInstalled
        if usageHeatmapEnabled { loadUsageHeatmap() }
        sparkleUpdater.automaticallyChecksForUpdates = sparkleAutoCheckEnabled
        sparkleUpdater.automaticallyDownloadsUpdates = sparkleAutoDownloadEnabled
        sparkleUpdater.start()

        // LocalizationManager is a separate ObservableObject reached through
        // `localization`, a computed property — not a stored, @Published
        // property of this class — so its own changes (language switch)
        // would not otherwise trigger a re-render of views that read
        // `model.localization.currentLanguage`. Forward its publisher.
        LocalizationManager.shared.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// See `MenuBarReading.all` — the logic lives in the core so it can be
    /// tested without a running app.
    var menuBarReadings: [MenuBarReading] {
        var activeEmails: [Provider: String] = [:]
        if let activeClaudeEmail { activeEmails[.anthropic] = activeClaudeEmail }
        if let activeCodexEmail { activeEmails[.openai] = activeCodexEmail }
        if let activeGeminiEmail { activeEmails[.gemini] = activeGeminiEmail }
        return MenuBarReading.all(
            accounts: accounts,
            usage: usage,
            // Honor the user's "Menu Bar Metric" choice in Settings — it was
            // previously hardcoded to .activeAccount, silently ignoring that
            // picker no matter what the user selected.
            metric: menuBarMetric,
            activeEmails: activeEmails
        )
    }

    func loadAccounts() {
        accounts = (try? store.load()) ?? []
        reloadActiveAccounts()
        loadInitialCachedUsage()
    }

    private func loadInitialCachedUsage() {
        if let activeEmail = activeClaudeEmail,
           let claudeAccount = accounts.first(where: { $0.provider == .anthropic && $0.email.lowercased() == activeEmail.lowercased() }),
           usage[claudeAccount.id] == nil,
           let cachedUsage = CLISwitcher.cachedClaudeUsage() {
            usage[claudeAccount.id] = cachedUsage
        }
    }

    func reloadActiveAccounts() {
        activeClaudeEmail = CLISwitcher.activeEmail(for: .anthropic, knownAccounts: accounts)
        activeCodexEmail = CLISwitcher.activeEmail(for: .openai, knownAccounts: accounts)
        activeGeminiEmail = CLISwitcher.activeEmail(for: .gemini, knownAccounts: accounts)
    }

    func isAccountActive(_ account: Account) -> Bool {
        switch account.provider {
        case .anthropic:
            guard let active = activeClaudeEmail else { return false }
            return active.lowercased() == account.email.lowercased()
        case .openai:
            guard let active = activeCodexEmail else { return false }
            return active.lowercased() == account.email.lowercased()
        case .gemini:
            guard let active = activeGeminiEmail else { return false }
            return active.lowercased() == account.email.lowercased()
        }
    }

    private var autoDismissBannerTask: Task<Void, Never>?

    /// Handles `fuelswitch://switch?id=<account.id>`, opened by a shell
    /// function from `LauncherScriptGenerator`. Silently ignores anything
    /// that isn't that exact shape — there's no UI to report a malformed URL to.
    func handleLauncherURL(_ url: URL) {
        guard url.scheme == "fuelswitch", url.host == "switch" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let account = accounts.first(where: { $0.id == id })
        else { return }
        switchTo(account: account)
    }

    func switchTo(account: Account) {
        guard !switchingProviders.contains(account.provider) else { return }
        autoDismissBannerTask?.cancel()
        // A manual switch always wins over auto-switch for a grace window —
        // otherwise the very next poll could immediately reverse the choice
        // the user just made by hand.
        lastManualSwitch[account.provider] = Date()
        switchingProviders.insert(account.provider)
        Task {
          defer { switchingProviders.remove(account.provider) }
          do {
            try await applyAccountSwitch(account)
            loginState = .switched(account.provider, account.email)
            autoDismissBannerTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                if case .switched = self?.loginState {
                    self?.dismissLoginState()
                }
            }
          } catch {
            loginState = .failed(account.provider, switchErrorDescription(error))
          }
        }
    }

    private func switchErrorDescription(_ error: Error) -> String {
        if error is CodexDesktopSync.SyncError { return t(.codexDesktopRestartFailed) }
        if error is OAuthError { return t(.sessionExpired) }
        return t(.operationFailed)
    }

    private func applyAccountSwitch(_ account: Account) async throws {
        let syncDesktop = account.provider == .openai && codexDesktopSyncEnabled
        // Validate credentials before asking a running desktop app to quit.
        let current = try await poller.accountForSwitch(account)
        if current.provider == .openai { try CLISwitcher.validateCodexSwitch(to: current) }
        try await CodexDesktopSync.performSwitch(enabled: syncDesktop) {
            try CLISwitcher.switch(to: current)
            loadAccounts()
            if let value = usage[current.id] { updateStatuslineCache(account: current, usage: value) }
        }
    }

    /// Forced: ignores `nextDueAt` (and therefore the backoff, and "too early
    /// for an automatic cycle") for every account, respecting only the hard
    /// 60-second floor since the last ATTEMPT (see
    /// `Poller.refreshAll(forced:)`) — without this, "Check now" pressed
    /// between two automatic cycles queried no accounts at all and merely
    /// flagged all seventeen as stale without changing a single number.
    func refreshNow() {
        Task { await refreshOnce(forced: true) }
    }

    /// Checks one account, from the button on its own cell. Useful when a
    /// single account is stale or was just rejected and the others are fine.
    func refreshAccount(id: String) {
        guard let account = accounts.first(where: { $0.id == id }) else { return }
        Task {
            usage[id] = await poller.refreshOne(account: account, interval: intervalSeconds)
            loadAccounts()
        }
    }

    func remove(id: String) {
        try? store.remove(id: id)
        usage[id] = nil
        loadAccounts()
        Task { await thresholdWatcher.forget(accountId: id) }
    }

    private let statuslineInstaller = StatuslineInstaller()
    @Published private(set) var isStatuslineInstalled = false

    func installStatusline() {
        try? statuslineInstaller.install()
        isStatuslineInstalled = statuslineInstaller.isInstalled
    }

    func uninstallStatusline() {
        try? statuslineInstaller.uninstall()
        isStatuslineInstalled = statuslineInstaller.isInstalled
    }

    /// Sets or clears an account's display nickname. `nil`/blank clears it,
    /// falling back to the email everywhere it's shown.
    func rename(id: String, nickname: String?) {
        guard var account = accounts.first(where: { $0.id == id }) else { return }
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        account.nickname = (trimmed?.isEmpty ?? true) ? nil : trimmed
        try? store.upsert(account)
        loadAccounts()
    }

    /// Redeems a rate-limit reset credit for an OpenAI Codex account.
    func redeemCodexReset(account: Account) {
        guard account.provider == .openai else { return }
        // User request: "W codex limit limitów nie resetuj realnie limitu"
        // Intentionally do not call OpenAI API to consume real rate-limit reset credits.
    }

    /// Opens Settings screen
    func openSettings() {
        showingSettings = true
        SettingsWindowController.shared.show(model: self)
    }

    /// What a sign-in is doing, and how the last one ended.
    ///
    /// This lives on the model rather than in a view because the panel closes
    /// the instant the browser takes focus — by the time there is anything to
    /// report, whatever started the sign-in is gone. The user comes back by
    /// clicking the menu bar icon, and the panel has to be able to tell them
    /// what happened.
    enum LoginState: Equatable {
        case idle
        case running(Provider)
        case failed(Provider, String)
        /// Signed in to an account that was not on the list before.
        case added(String)
        /// Signed in again to an account already on the list. Nothing is
        /// duplicated — the identity is provider:email, so the entry is
        /// overwritten with fresh tokens — but the user asked for it and
        /// deserves to be told that is what happened.
        case reconnected(String)
        /// Switched active account in CLI
        case switched(Provider, String)
        /// The app itself switched the active account because the previous
        /// one ran out of quota — distinct from `.switched`, which the user
        /// triggered by clicking "Engage".
        case autoSwitched(Provider, from: String, to: String)
    }

    @Published private(set) var loginState: LoginState = .idle

    /// Starts a sign-in in the background and reports through `loginState`.
    /// There is no name to ask for — the provider tells us the email — so this
    /// takes only the provider and opens the browser immediately.
    ///
    /// The task handle is kept on `self` so that `cancelLogin()` can genuinely
    /// interrupt it: that is the only way an abandoned sign-in releases the
    /// `CallbackListener` instead of holding it — and, for Codex, port 1455 —
    /// for the life of the process.
    /// Persists the pasted client to disk, then immediately continues into
    /// the normal Gemini sign-in flow.
    func saveGeminiCredentialsAndConnect(clientID: String, clientSecret: String) {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedSecret.isEmpty else { return }
        try? GeminiClientStore.default.save(
            GeminiClientCredentials(clientID: trimmedID, clientSecret: trimmedSecret)
        )
        GeminiSetupWindowController.shared.close()
        startLogin(provider: .gemini)
    }

    func startLogin(provider: Provider) {
        if provider == .gemini, !FuelSwitchConstants.geminiIsConfigured {
            GeminiSetupWindowController.shared.show(model: self)
            return
        }
        loginTask?.cancel()
        loginState = .running(provider)
        let knownIDs = Set(accounts.map(\.id))
        loginTask = Task { [store] in
            let flow = LoginFlow(store: store) { url in
                NSWorkspace.shared.open(url)
            }
            do {
                let added = try await flow.logIn(provider: provider)
                guard !Task.isCancelled else { return }
                loadAccounts()
                await checkImmediately(added)
                loginState = knownIDs.contains(added.id)
                    ? .reconnected(added.email)
                    : .added(added.email)
            } catch {
                guard !Task.isCancelled else { return }
                loginState = .failed(provider, errorDescription(error, provider: provider))
            }
        }
    }

    /// A freshly added account is checked at once and on its own, rather than
    /// through `refreshNow()`. That path skips two things which made a sign-in
    /// end in an empty row and look as though nothing had happened: the hard
    /// 60-second floor inherited from attempts with the old token (the
    /// poller's state keys on the account, not on the token) and the
    /// `guard !isRefreshing` that silently drops the request whenever an
    /// automatic cycle happens to be running — and a browser sign-in takes long
    /// enough to land in one.
    private func checkImmediately(_ account: Account) async {
        await poller.forgetState(id: account.id)
        await thresholdWatcher.forget(accountId: account.id)
        usage[account.id] = await poller.refresh(account: account, interval: intervalSeconds)
        loadAccounts()
    }

    /// Clears whatever the last sign-in left on screen.
    func dismissLoginState() {
        loginState = .idle
    }

    /// Called from "Cancel" — whether or not a sign-in is in progress (with no
    /// running task it is a safe no-op).
    func cancelLogin() {
        loginTask?.cancel()
        loginTask = nil
        loginState = .idle
    }

    /// An occupied port 1455 is the only error the user can fix themselves, so
    /// we say plainly what is blocking them.
    func errorDescription(_ error: Error, provider: Provider) -> String {
        if case LoginFlowError.providerNotConfigured = error {
            return "Gemini sign-in isn't configured yet. Use \"Connect Gemini\" to enter your own Google Cloud OAuth client."
        }
        if case OAuthError.portInUse = error, provider == .openai {
            return "Port 1455 is in use. Quit any running `codex login` and try again."
        }
        if case OAuthError.stateMismatch = error {
            return "The browser's reply does not match this sign-in. Try again."
        }
        if case OAuthError.timedOut = error {
            return "No sign-in came back from the browser within five minutes. Try again."
        }
        if case OAuthError.incompleteCodexIdentity = error {
            return "Codex did not return a complete account identity (email or account id). Try signing in again."
        }
        if error is AnthropicProfileError {
            return "Could not read the Claude account identity. Try again."
        }
        return "Sign-in failed: \(error)"
    }

    private func startLoop() {
        loopTask = Task {
            while !Task.isCancelled {
                await refreshOnce()
                await checkForUpdateIfDue()
                await waitForNextRefresh()
            }
        }
    }

    /// Sleeps up to `intervalSeconds`, but in one-second slices, re-reading the
    /// current value each time — so a change on the Settings slider takes
    /// effect immediately (shortening it wakes the loop within a second)
    /// instead of waiting out the previously configured gap, which may be half
    /// an hour. The refresh still happens only once per turn of the loop, at
    /// its start, so this introduces no extra duplicate request.
    private func waitForNextRefresh() async {
        var elapsed: TimeInterval = 0
        while elapsed < effectiveIntervalSeconds, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            elapsed += 1
        }
    }

    /// `intervalSeconds`, shortened when `adaptiveRefreshEnabled` and the CLI
    /// was used recently. See `AdaptiveRefreshPolicy`.
    private var effectiveIntervalSeconds: TimeInterval {
        guard adaptiveRefreshEnabled else { return intervalSeconds }
        return AdaptiveRefreshPolicy.effectiveInterval(baseInterval: intervalSeconds, sinceLastCliActivity: timeSinceLastCliActivity())
    }

    private func timeSinceLastCliActivity() -> TimeInterval? {
        let urls = [CLISwitcher.claudeConfigURL, CLISwitcher.codexAuthURL, CLISwitcher.geminiOAuthCredsURL]
        let mtimes = urls.compactMap { url -> Date? in
            (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        }
        guard let mostRecent = mtimes.max() else { return nil }
        return Date().timeIntervalSince(mostRecent)
    }

    /// The only place that actually queries the `Poller`. Checking and setting
    /// `isRefreshing` has no `await` between the two, so on `@MainActor` it is
    /// indivisible — the startup loop and a manual "Check now" never query the
    /// providers at the same time: whichever arrives second simply does
    /// nothing, instead of duplicating requests. `forced` passes straight
    /// through to `Poller.refreshAll(forced:)` — the automatic loop never
    /// sets it, "Check now" always does.
    ///
    /// `onResult` publishes into `usage` AFTER EACH ACCOUNT rather than after
    /// the whole series of seventeen requests — without it the panel would sit
    /// empty for 15-20 s at app start even though the first results are ready
    /// within a fraction of a second. The final `usage = ...` assignment
    /// below stays as an end-of-pass consistency guarantee, in case anything
    /// bypassed `onResult`.
    ///
    /// Accounts are reloaded here (not only in `init`, `remove` and after a
    /// sign-in) for two reasons: `needsReauth`, written by the `Poller` after
    /// an `invalid_grant`, has to reach the view in the same cycle in which it
    /// appeared rather than after an app restart — and those same
    /// `accounts` drive `sorted(_:)` in `MenuContentView`.
    private func refreshOnce(forced: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        usage = await poller.refreshAll(
            interval: intervalSeconds,
            forced: forced,
            onResult: { [weak self] id, accountUsage in
                guard let self else { return }
                self.usage[id] = accountUsage
                guard let account = self.accounts.first(where: { $0.id == id }) else { return }
                Task { await self.checkThresholds(account: account, usage: accountUsage) }
                self.checkAutoSwitch(provider: account.provider)
                self.updateStatuslineCache(account: account, usage: accountUsage)
            }
        )
        loadAccounts()
        isRefreshing = false
    }

    /// Posts a notification for every newly-crossed threshold on this
    /// account's session and weekly windows. Skipped for anything but fresh
    /// data — a cached or error result carries the same percent as the last
    /// poll, which `ThresholdWatcher` would not re-fire on anyway, but there
    /// is no reason to even ask.
    private func checkThresholds(account: Account, usage: AccountUsage) async {
        guard notificationsEnabled, usage.staleness == .fresh else { return }
        let thresholds = notificationThresholds
        for window in [usage.session, usage.weekly] {
            guard let crossing = await thresholdWatcher.evaluate(
                accountId: account.id,
                windowLabel: window.label,
                percent: window.percent,
                thresholds: thresholds
            ) else { continue }

            let windowName = window.label == "5 hours" ? t(.fiveHourSession) : t(.weeklyQuota)
            NotificationManager.postThresholdNotification(
                accountId: account.id,
                windowLabel: crossing.windowLabel,
                title: String(format: t(.notificationThresholdTitle), account.provider.displayName),
                body: String(format: t(.notificationThresholdBody), windowName, crossing.threshold),
                soundEnabled: notificationSoundEnabled
            )
        }
    }

    /// Switches the active CLI account away from one that just ran fully
    /// dry, respecting the manual-switch grace window and the cooldown
    /// between automatic switches (see the properties above).
    private func checkAutoSwitch(provider: Provider) {
        guard autoSwitchEnabled, !switchingProviders.contains(provider) else { return }
        let now = Date()
        if let manual = lastManualSwitch[provider], now.timeIntervalSince(manual) < Self.manualSwitchGrace {
            return
        }
        if let auto = lastAutoSwitch[provider], now.timeIntervalSince(auto) < Self.autoSwitchCooldown {
            return
        }

        let activeEmail: String?
        switch provider {
        case .anthropic: activeEmail = activeClaudeEmail
        case .openai: activeEmail = activeCodexEmail
        case .gemini: activeEmail = activeGeminiEmail
        }

        guard let decision = AutoSwitchDecider.decide(
            provider: provider,
            accounts: accounts,
            usage: usage,
            activeEmail: activeEmail
        ) else { return }

        switchingProviders.insert(provider)
        Task {
          defer { switchingProviders.remove(provider) }
          do {
            try await applyAccountSwitch(decision.to)
            lastAutoSwitch[provider] = now
            loginState = .autoSwitched(provider, from: decision.from.email, to: decision.to.email)
            NotificationManager.postAutoSwitchNotification(
                title: String(format: t(.autoSwitchNotificationTitle), provider.displayName),
                body: String(format: t(.autoSwitchNotificationBody), decision.from.email, decision.to.email),
                identifier: "autoswitch|\(provider.rawValue)|\(now.timeIntervalSince1970)"
            )
          } catch {
            lastAutoSwitch[provider] = Date()
            loginState = .failed(provider, switchErrorDescription(error))
          }
        }
    }

    /// Writes the account's usage to its provider's statusline cache file, so
    /// the generated statusline script can show it — but only for the
    /// account actually active on that provider's CLI, and only when the
    /// poll succeeded (a stale cached result carries a last-known percent
    /// that's already whatever the script would otherwise still be showing).
    private func updateStatuslineCache(account: Account, usage: AccountUsage) {
        guard statuslineEnabled, usage.staleness == .fresh else { return }
        let activeEmail: String?
        switch account.provider {
        case .anthropic: activeEmail = activeClaudeEmail
        case .openai: activeEmail = activeCodexEmail
        case .gemini: activeEmail = activeGeminiEmail
        }
        guard activeEmail == account.email, let cache = statuslineCaches[account.provider] else { return }

        let snapshot = StatuslineSnapshot(
            provider: account.provider,
            email: account.email,
            sessionPercent: (usage.session.percent * 10).rounded() / 10,
            weeklyPercent: (usage.weekly.percent * 10).rounded() / 10,
            fetchedAt: usage.fetchedAt
        )
        try? cache.write(snapshot)
    }
}
