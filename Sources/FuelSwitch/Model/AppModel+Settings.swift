import SwiftUI
import AppKit
import ServiceManagement
import FuelSwitchCore

extension AppModel {
    func openSettings() {
        showingSettings = true
        SettingsWindowController.shared.show(model: self)
    }

    func updateThemeAppearance() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch self.appTheme {
            case "dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
            default: NSApplication.shared.appearance = nil
            }
        }
    }

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
        launchesAtLogin = SMAppService.mainApp.status == .enabled
        if launchesAtLogin != wanted, launchAtLoginProblem == nil {
            launchAtLoginProblem = SMAppService.mainApp.status == .requiresApproval
                ? "Waiting for approval in System Settings, under Login Items."
                : nil
        }
    }

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

    func toggleNotificationThreshold(_ threshold: Int) {
        if notificationThresholds.contains(threshold) {
            notificationThresholds.removeAll { $0 == threshold }
        } else {
            notificationThresholds.append(threshold)
        }
    }

    func installStatusline() {
        try? statuslineInstaller.install()
        isStatuslineInstalled = statuslineInstaller.isInstalled
    }

    func uninstallStatusline() {
        try? statuslineInstaller.uninstall()
        isStatuslineInstalled = statuslineInstaller.isInstalled
    }

    func dismissUpdate() {
        preferences.dismissedUpdateVersion = availableUpdate?.version
        availableUpdate = nil
    }

    func openUpdate() {
        sparkleUpdater.checkForUpdates()
    }

    func checkForUpdateIfDue() async {
        let now = Date()
        if let last = lastUpdateCheck, now.timeIntervalSince(last) < AppModel.updateCheckInterval { return }
        lastUpdateCheck = now
        guard let found = try? await UpdateChecker().check(currentVersion: currentVersion) else { return }
        guard preferences.dismissedUpdateVersion != found.version else { return }
        availableUpdate = found
    }

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
}
