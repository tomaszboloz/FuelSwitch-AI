import SwiftUI
import AppKit
import Observation
import ServiceManagement
import FuelSwitchCore

@Observable
@MainActor
final class AppModel {
    private(set) var accounts: [Account] = []
    private(set) var usage: [String: AccountUsage] = [:]
    private(set) var isRefreshing = false

    /// Currently active account emails in the CLI config files.
    private(set) var activeClaudeEmail: String?
    private(set) var activeCodexEmail: String?
    private(set) var activeGeminiEmail: String?

    /// Theme preference: "system", "dark", or "light"
    var appTheme: String = Preferences().appTheme {
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
    var widgetStyle: String = Preferences().widgetStyle {
        didSet {
            preferences.widgetStyle = widgetStyle
            FloatingWidgetController.shared.updateStyle()
        }
    }

    /// Whether the Settings screen is being shown in the menu panel
    var showingSettings: Bool = false

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
    var showsPercentInMenuBar = Preferences().showsPercentInMenuBar {
        didSet { preferences.showsPercentInMenuBar = showsPercentInMenuBar }
    }

    /// Whether the floating desktop widget HUD is active.
    var showFloatingWidget = Preferences().showFloatingWidget {
        didSet {
            preferences.showFloatingWidget = showFloatingWidget
            FloatingWidgetController.shared.setVisible(showFloatingWidget)
        }
    }

    /// Transparency / opacity of the desktop HUD.
    var widgetOpacity: Double = Preferences().widgetOpacity {
        didSet {
            preferences.widgetOpacity = widgetOpacity
            FloatingWidgetController.shared.updateOpacity(widgetOpacity)
        }
    }

    /// Whether the desktop HUD floats on top of other windows.
    var widgetAlwaysOnTop: Bool = Preferences().widgetAlwaysOnTop {
        didSet {
            preferences.widgetAlwaysOnTop = widgetAlwaysOnTop
            FloatingWidgetController.shared.updateAlwaysOnTop(widgetAlwaysOnTop)
        }
    }

    /// Which question the menu bar answers. See `MenuBarMetric`.
    var menuBarMetric = Preferences().menuBarMetric {
        didSet { preferences.menuBarMetric = menuBarMetric }
    }

    /// The slider in Settings is limited to 60...1800; `Preferences` clamps to
    /// the same bounds on read and write, so here we merely mirror the result
    /// of that clamp into `intervalSeconds` rather than computing it twice.
    var intervalSeconds: Double = Preferences().refreshIntervalSeconds {
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
    private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled
    /// Set when the system refused the last change, so the panel can say so
    /// instead of quietly flipping the switch back.
    private(set) var launchAtLoginProblem: String?

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
    private(set) var availableUpdate: AvailableUpdate?

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
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.url)
    }

    /// Checked at launch and every six hours after. GitHub allows sixty
    /// unauthenticated calls an hour, so this is nowhere near anything, and a
    /// failed check is silent by design.
    private static let updateCheckInterval: TimeInterval = 6 * 3600
    private var lastUpdateCheck: Date?
    private(set) var isCheckingForUpdate = false
    /// Set only by a manual check, so a silent background poll never pops an
    /// "up to date" message the user did not ask for.
    private(set) var justConfirmedUpToDate = false

    private func checkForUpdateIfDue() async {
        let now = Date()
        if let last = lastUpdateCheck, now.timeIntervalSince(last) < Self.updateCheckInterval {
            return
        }
        lastUpdateCheck = now
        guard let found = await UpdateChecker().check(currentVersion: currentVersion) else { return }
        guard preferences.dismissedUpdateVersion != found.version else { return }
        availableUpdate = found
    }

    /// Bypasses the six-hour throttle so a user pressing "Check for Updates"
    /// gets an answer right away.
    func checkForUpdateNow() {
        guard !isCheckingForUpdate else { return }
        isCheckingForUpdate = true
        justConfirmedUpToDate = false
        Task {
            lastUpdateCheck = Date()
            let found = await UpdateChecker().check(currentVersion: currentVersion)
            isCheckingForUpdate = false
            guard let found else {
                justConfirmedUpToDate = true
                return
            }
            preferences.dismissedUpdateVersion = nil
            availableUpdate = found
        }
    }

    private let preferences = Preferences()
    private let store = AccountStore.default
    private let poller: Poller
    private var loopTask: Task<Void, Never>?
    /// A handle on the sign-in currently in progress. Kept here rather than in
    /// the view so that "Cancel" and closing the window can genuinely interrupt
    /// it: `LoginFlow.logIn` responds to cancellation of this task by releasing
    /// the `CallbackListener` (see `LoginFlow.awaitCodeWithTimeout`), instead
    /// of merely hiding the window and leaving the listener — and, for Codex,
    /// port 1455 — occupied for the life of the process.
    private var loginTask: Task<Void, Never>?

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
            ]
        )
        loadAccounts()
        startLoop()
        updateThemeAppearance()
        FloatingWidgetController.shared.configure(with: self)
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
            // The menu bar, cockpit and HUD must describe the same account.
            // Alternative aggregate metrics belong in reporting, not in the
            // live account indicator.
            metric: .activeAccount,
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

    func switchTo(account: Account) {
        autoDismissBannerTask?.cancel()
        do {
            try CLISwitcher.switch(to: account)
            reloadActiveAccounts()
            loginState = .switched(account.provider, account.email)
            autoDismissBannerTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                if case .switched = self?.loginState {
                    self?.dismissLoginState()
                }
            }
        } catch {
            loginState = .failed(account.provider, "Failed to switch CLI account: \(error.localizedDescription)")
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
    }

    private(set) var loginState: LoginState = .idle

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
        while elapsed < intervalSeconds, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            elapsed += 1
        }
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
                self?.usage[id] = accountUsage
            }
        )
        loadAccounts()
        isRefreshing = false
    }
}
