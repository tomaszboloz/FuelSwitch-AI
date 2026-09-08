import SwiftUI
import AppKit
import FuelSwitchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void

    @State private var snippetCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FuelSwitchTheme.amber)
                    Text(model.t(.settings))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                }

                Spacer()

                Button(model.t(.done), action: close)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(FuelSwitchTheme.amber.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(FuelSwitchTheme.amber.opacity(0.4), lineWidth: 0.8)
                    )
                    .foregroundStyle(FuelSwitchTheme.amber)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FuelSwitchTheme.bgPanel)

            Divider().background(FuelSwitchTheme.borderSubtle)

            // High-density, 2-column or spacious single-column settings to avoid vertical scrolling
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // SECTION 1: Appearance, Theme & Language
                    settingsCard(title: model.t(.settingsAppearance), icon: "paintbrush.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            // Language Picker
                            HStack {
                                Text(model.t(.language))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { model.localization.currentLanguage },
                                    set: { model.localization.setLanguage($0) }
                                )) {
                                    ForEach(AppLanguage.allCases) { lang in
                                        Text(lang.nativeName).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 150)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            // Theme Selection
                            HStack {
                                Text(model.t(.theme))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                Spacer()
                                Picker("", selection: $model.appTheme) {
                                    Image(systemName: "display").tag("system").help(model.t(.themeSystem))
                                    Image(systemName: "sun.max.fill").tag("light").help(model.t(.themeLight))
                                    Image(systemName: "moon.fill").tag("dark").help(model.t(.themeDark))
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            }
                        }
                    }

                    // SECTION 2: Floating Desktop HUD Widget Settings
                    settingsCard(title: model.t(.hudTitle), icon: "macwindow.on.rectangle") {
                        VStack(alignment: .leading, spacing: 10) {
                            // Main Toggle
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.hudToggle))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.showFloatingWidget)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            if model.showFloatingWidget {
                                Divider().background(FuelSwitchTheme.borderSubtle)

                                // Widget Style Picker on its own row
                                HStack {
                                    Text(model.t(.hudStyle))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    Spacer()
                                    Picker("", selection: $model.widgetStyle) {
                                        Image(systemName: "rectangle.split.2x1").tag("expanded").help(model.t(.hudExpanded))
                                        Image(systemName: "capsule").tag("compact").help(model.t(.hudCompact))
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 100)
                                }

                                Divider().background(FuelSwitchTheme.borderSubtle)

                                // Opacity and Always on Top
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(model.t(.hudOpacity))
                                                .font(.system(size: 10.5, weight: .medium))
                                                .foregroundStyle(FuelSwitchTheme.textPrimary)
                                            Spacer()
                                            Text("\(Int(model.widgetOpacity * 100))%")
                                                .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                                                .foregroundStyle(FuelSwitchTheme.amber)
                                        }
                                        Slider(value: $model.widgetOpacity, in: 0.3...1.0, step: 0.05)
                                    }

                                    HStack(alignment: .center, spacing: 12) {
                                        Text(model.t(.hudAlwaysOnTop))
                                            .font(.system(size: 11))
                                            .foregroundStyle(FuelSwitchTheme.textPrimary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 16)
                                        Toggle("", isOn: $model.widgetAlwaysOnTop)
                                            .labelsHidden()
                                            .toggleStyle(.switch)
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 3: Menu Bar Display Settings
                    settingsCard(title: model.t(.menuBarDisplay), icon: "menubar.rectangle") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(model.t(.menuBarMetric))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                Spacer()
                                Picker("", selection: $model.menuBarMetric) {
                                    ForEach(MenuBarMetric.allCases) { metric in
                                        Text(metricTitle(metric)).tag(metric)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: 150)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            HStack {
                                Text(model.t(.menuBarIconStyleLabel))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                Spacer()
                                Picker("", selection: $model.menuBarIconStyle) {
                                    ForEach(MenuBarIconStyle.allCases) { style in
                                        Text(iconStyleTitle(style)).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: 150)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.showPercentInMenuBar))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.showsPercentInMenuBar)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.paceEstimationToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.paceEstimationEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                        }
                    }

                    // SECTION 3B: Notifications
                    settingsCard(title: model.t(.notificationsTitle), icon: "bell.badge.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.notificationsToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.notificationsEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            if model.notificationsEnabled {
                                Divider().background(FuelSwitchTheme.borderSubtle)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(model.t(.notificationThresholdsLabel))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    HStack(spacing: 16) {
                                        ForEach([75, 90, 95], id: \.self) { threshold in
                                            Button {
                                                model.toggleNotificationThreshold(threshold)
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: model.notificationThresholds.contains(threshold) ? "checkmark.square.fill" : "square")
                                                        .foregroundStyle(model.notificationThresholds.contains(threshold) ? FuelSwitchTheme.amber : FuelSwitchTheme.textTertiary)
                                                    Text("\(threshold)%")
                                                        .font(.system(size: 11))
                                                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                Divider().background(FuelSwitchTheme.borderSubtle)

                                HStack(alignment: .center, spacing: 12) {
                                    Text(model.t(.notificationsSoundToggle))
                                        .font(.system(size: 11))
                                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 16)
                                    Toggle("", isOn: $model.notificationSoundEnabled)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                }
                            }
                        }
                    }

                    // SECTION 3C: Auto-Switch
                    settingsCard(title: model.t(.autoSwitchTitle), icon: "arrow.triangle.swap") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.autoSwitchToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.autoSwitchEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Text(model.t(.autoSwitchExplanation))
                                .font(.system(size: 9.5))
                                .foregroundStyle(FuelSwitchTheme.textTertiary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // SECTION 4: Synchronization & Autostart
                    settingsCard(title: model.t(.telemetryAutostart), icon: "arrow.triangle.2.circlepath") {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(model.t(.checkQuotaEvery))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    Spacer()
                                    Text("\(Int(model.intervalSeconds / 60)) min")
                                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                                        .foregroundStyle(FuelSwitchTheme.amber)
                                }
                                Slider(value: $model.intervalSeconds, in: 60...1800, step: 60)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.adaptiveRefreshToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.adaptiveRefreshEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Divider().background(FuelSwitchTheme.borderSubtle)

                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.openAtLogin))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: Binding(
                                    get: { model.launchesAtLogin },
                                    set: { model.setLaunchAtLogin($0) }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                            }

                            if let problem = model.launchAtLoginProblem {
                                Text(problem)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(FuelSwitchTheme.amber)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // SECTION 4B: Per-Profile Launcher
                    settingsCard(title: model.t(.launcherTitle), icon: "terminal.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.t(.launcherExplanation))
                                .font(.system(size: 10.5))
                                .foregroundStyle(FuelSwitchTheme.textSecondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                copyShellSnippet()
                            } label: {
                                Text(snippetCopied ? model.t(.shellSnippetCopied) : model.t(.copyShellSnippet))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(FuelSwitchTheme.amber.opacity(0.14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8)
                            )
                            .foregroundStyle(FuelSwitchTheme.amber)
                            .disabled(model.accounts.isEmpty)
                        }
                    }

                    // SECTION 4C: Claude Code Statusline
                    settingsCard(title: model.t(.statuslineTitle), icon: "chart.bar.doc.horizontal") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.statuslineToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.statuslineEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Text(model.t(.statuslineExplanation))
                                .font(.system(size: 10.5))
                                .foregroundStyle(FuelSwitchTheme.textSecondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                if model.isStatuslineInstalled {
                                    model.uninstallStatusline()
                                } else {
                                    model.installStatusline()
                                }
                            } label: {
                                Text(model.isStatuslineInstalled ? model.t(.statuslineUninstall) : model.t(.statuslineInstall))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(FuelSwitchTheme.amber.opacity(0.14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8)
                            )
                            .foregroundStyle(FuelSwitchTheme.amber)
                        }
                    }

                    // SECTION 4D: Usage Heatmap
                    settingsCard(title: model.t(.usageHeatmapTitle), icon: "square.grid.3x3.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.usageHeatmapToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.usageHeatmapEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Text(model.t(.usageHeatmapExplanation))
                                .font(.system(size: 10.5))
                                .foregroundStyle(FuelSwitchTheme.textSecondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            if model.usageHeatmapEnabled {
                                UsageHeatmapView(
                                    days: model.usageHeatmapDays,
                                    isLoading: model.usageHeatmapIsLoading,
                                    loadingText: model.t(.usageHeatmapLoading),
                                    emptyText: model.t(.usageHeatmapEmpty),
                                    summarySuffix: model.t(.usageHeatmapSummarySuffix)
                                )
                            }
                        }
                    }

                    // SECTION 4E: Sparkle Automatic Updates
                    settingsCard(title: model.t(.sparkleUpdatesTitle), icon: "arrow.triangle.2.circlepath") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.sparkleAutoCheckToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.sparkleAutoCheckEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            HStack(alignment: .center, spacing: 12) {
                                Text(model.t(.sparkleAutoDownloadToggle))
                                    .font(.system(size: 11))
                                    .foregroundStyle(model.sparkleAutoCheckEnabled ? FuelSwitchTheme.textPrimary : FuelSwitchTheme.textTertiary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 16)
                                Toggle("", isOn: $model.sparkleAutoDownloadEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .disabled(!model.sparkleAutoCheckEnabled)
                            }

                            Text(model.t(.sparkleExplanation))
                                .font(.system(size: 10.5))
                                .foregroundStyle(FuelSwitchTheme.textSecondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack {
                                Button {
                                    model.checkForSparkleUpdateNow()
                                } label: {
                                    Text(model.t(.sparkleCheckNowButton))
                                        .font(.system(size: 9.5, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(FuelSwitchTheme.amber)
                                Spacer()
                            }
                        }
                    }

                    // SECTION 5: Security & Credits
                    settingsCard(title: model.t(.securityTitle), icon: "shield.checkered") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(String(format: model.t(.versionLabel), model.currentVersion))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(model.t(.author) + ":")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                                    Link("Tomasz Bołoz (damtox.pl)", destination: URL(string: "https://www.damtox.pl")!)
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(FuelSwitchTheme.amber)
                                }
                            }

                            HStack {
                                Button {
                                    model.checkForUpdateNow()
                                } label: {
                                    Text(model.isCheckingForUpdate ? model.t(.checkingForUpdates) : model.t(.checkForUpdates))
                                        .font(.system(size: 9.5, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(FuelSwitchTheme.amber)
                                .disabled(model.isCheckingForUpdate)

                                if model.justConfirmedUpToDate {
                                    Text(model.t(.upToDate))
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(FuelSwitchTheme.textTertiary)
                                }
                                Spacer()
                            }

                            Text(model.t(.localCredentialsNotice))
                                .font(.system(size: 9.5))
                                .foregroundStyle(FuelSwitchTheme.textTertiary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(minHeight: 540)
        .background(FuelSwitchTheme.bgDeep)
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    private func metricTitle(_ metric: MenuBarMetric) -> String {
        switch metric {
        case .activeAccount: model.t(.metricActive)
        case .bestAccount: model.t(.metricBest)
        case .worstAccount: model.t(.metricBusiest)
        case .accountsWithRoom: model.t(.metricWithRoom)
        }
    }

    private func iconStyleTitle(_ style: MenuBarIconStyle) -> String {
        switch style {
        case .gauge: model.t(.iconStyleGauge)
        case .battery: model.t(.iconStyleBattery)
        case .percentOnly: model.t(.iconStylePercentOnly)
        case .monochrome: model.t(.iconStyleMonochrome)
        }
    }

    private func copyShellSnippet() {
        let snippet = LauncherScriptGenerator.shellFunction(accounts: model.accounts)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        snippetCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            snippetCopied = false
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber)
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
            }

            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(FuelSwitchTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(FuelSwitchTheme.borderSubtle, lineWidth: 1)
        )
    }
}
