import SwiftUI
import FuelSwitchCore

struct SettingsAppearanceSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsCard(title: model.t(.settingsAppearance), icon: "paintbrush.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Picker(model.t(.interfaceTemplate), selection: $model.interfaceTemplate) {
                    ForEach(InterfaceTemplate.allCases) { template in
                        Text(model.t(template.titleKey)).tag(template)
                    }
                }
                .pickerStyle(.menu)

                Text(model.t(.templateHelp))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

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
    }
}
