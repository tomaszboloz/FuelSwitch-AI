import SwiftUI

struct SettingsSyncSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            desktopSyncCards
            telemetryCard
        }
    }

    private var desktopSyncCards: some View {
        Group {
            SettingsCard(title: model.t(.codexDesktopSyncTitle), icon: "desktopcomputer") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(model.t(.codexDesktopSyncTitle), isOn: $model.codexDesktopSyncEnabled)
                        .disabled(model.switchingProviders.contains(.openai))
                        .toggleStyle(.switch)
                        .font(.system(size: 11))
                    Text(model.t(.codexDesktopSyncHelp))
                        .font(.system(size: 10))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsCard(title: model.t(.antigravitySyncTitle), icon: "arrow.triangle.2.circlepath") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(model.t(.antigravitySyncTitle), isOn: $model.antigravitySyncEnabled)
                        .disabled(model.switchingProviders.contains(.gemini))
                        .toggleStyle(.switch)
                        .font(.system(size: 11))
                    Text(model.t(.antigravitySyncHelp))
                        .font(.system(size: 10))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var telemetryCard: some View {
        SettingsCard(title: model.t(.telemetryAutostart), icon: "arrow.triangle.2.circlepath") {
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
    }
}
