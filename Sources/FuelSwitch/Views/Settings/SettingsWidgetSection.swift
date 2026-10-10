import SwiftUI

struct SettingsWidgetSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsCard(title: model.t(.hudTitle), icon: "macwindow.on.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
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
    }
}
