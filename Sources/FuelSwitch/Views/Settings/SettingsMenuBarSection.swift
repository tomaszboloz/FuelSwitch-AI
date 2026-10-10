import SwiftUI
import FuelSwitchCore

struct SettingsMenuBarSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsCard(title: model.t(.menuBarDisplay), icon: "menubar.rectangle") {
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
}
