import SwiftUI
import AppKit
import FuelSwitchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider().background(FuelSwitchTheme.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsAppearanceSection(model: model)
                    SettingsWidgetSection(model: model)
                    SettingsMenuBarSection(model: model)
                    SettingsAutomationSection(model: model)
                    SettingsSyncSection(model: model)
                    SettingsToolsSection(model: model)
                    SettingsIntegrationsSection(model: model)
                    SettingsSecuritySection(model: model)
                }
                .padding(14)
            }
        }
        .frame(minHeight: 540)
        .background(FuelSwitchTheme.bgDeep)
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    private var headerBar: some View {
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
                .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.amber.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(FuelSwitchTheme.amber.opacity(0.4), lineWidth: 0.8))
                .foregroundStyle(FuelSwitchTheme.amber)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(FuelSwitchTheme.bgPanel)
    }
}
