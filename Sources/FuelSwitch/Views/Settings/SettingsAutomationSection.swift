import SwiftUI

struct SettingsAutomationSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            notificationsCard
            autoSwitchCard
        }
    }

    private var notificationsCard: some View {
        SettingsCard(title: model.t(.notificationsTitle), icon: "bell.badge.fill") {
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
    }

    private var autoSwitchCard: some View {
        SettingsCard(title: model.t(.autoSwitchTitle), icon: "arrow.triangle.swap") {
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
    }
}
