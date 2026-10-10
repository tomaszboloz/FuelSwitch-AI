import SwiftUI
import AppKit
import FuelSwitchCore

struct MenuContentView: View {
    @ObservedObject var model: AppModel
    @State private var selectedFilter: ProviderFilter = .all

    private let panelWidth: CGFloat = 700

    var isSigningIn: Bool {
        if case .running = model.loginState { return true }
        return false
    }

    var bannerArea: some View {
        MenuBannerArea(model: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.showingSettings {
                SettingsView(model: model, close: { model.showingSettings = false })
            } else {
                MenuCockpitHeader(model: model, isSigningIn: isSigningIn)
                bannerArea

                if model.accounts.isEmpty {
                    MenuEmptyState(model: model)
                } else {
                    MenuCockpitHero(model: model)
                    MenuFilterToolbar(model: model, selectedFilter: $selectedFilter)
                    MenuAccountsList(model: model, selectedFilter: selectedFilter, isSigningIn: isSigningIn)
                }

                Divider().background(FuelSwitchTheme.borderSubtle)
                cockpitFooter
            }
        }
        .frame(width: panelWidth)
        .background(FuelSwitchTheme.bgDeep)
        .preferredColorScheme(model.colorScheme)
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
        .onAppear {
            model.showingSettings = false
            model.reloadActiveAccounts()
        }
    }

    private var cockpitFooter: some View {
        HStack(spacing: 8) {
            Text(String(format: model.t(.accountsCount), model.accounts.count))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.textTertiary)

            Spacer()

            Text(String(format: model.t(.versionLabel), model.currentVersion))
                .font(.system(size: 9.5))
                .foregroundStyle(FuelSwitchTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(FuelSwitchTheme.bgPanel)
    }
}
