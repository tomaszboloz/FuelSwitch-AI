import SwiftUI

struct SettingsSecuritySection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsCard(title: model.t(.securityTitle), icon: "shield.checkered") {
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

                    updateStatusView
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

    @ViewBuilder
    private var updateStatusView: some View {
        if model.justConfirmedUpToDate {
            Text(model.t(.upToDate))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.textTertiary)
        } else if model.updateCheckFailed {
            Text(model.t(.updateCheckFailed))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.amber)
        } else if let update = model.availableUpdate {
            Text(String(format: model.t(.versionAvailable), update.version))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.amber)
            Button {
                model.openUpdate()
            } label: {
                Text(model.t(.download))
                    .font(.system(size: 9.5, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(FuelSwitchTheme.amber)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(FuelSwitchTheme.amber.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
