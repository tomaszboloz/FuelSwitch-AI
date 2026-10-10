import AppKit
import SwiftUI
import FuelSwitchCore

/// Resizable native workspace view.
struct NativeTemplateView: View {
    @ObservedObject var model: AppModel
    @State private var provider: String = "all"
    @State private var search = ""
    @State private var activeOnly = false
    @State private var selection: Account.ID?

    private var accounts: [Account] {
        model.accounts.filter {
            (provider == "all" || $0.provider.rawValue == provider) &&
            (!activeOnly || model.isAccountActive($0)) &&
            (search.isEmpty || ($0.email + " " + ($0.nickname ?? "") + " " + $0.provider.displayName)
                .localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if geometry.size.width >= 900 {
                    sidebar
                    Divider()
                }
                mainContent(geometry: geometry)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(model.colorScheme)
        .environment(\.locale, Locale(identifier: model.localization.currentLanguage.rawValue))
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
        .onAppear { model.reloadActiveAccounts() }
    }

    private var sidebar: some View {
        List(selection: $provider) {
            Label(model.t(.allTanks), systemImage: "square.stack").tag("all")
            ForEach(Provider.allCases) { item in
                Text(item.displayName).tag(item.rawValue)
            }
        }
        .listStyle(.sidebar)
        .frame(width: 220)
    }

    private func mainContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TextField(model.t(.searchAccounts), text: $search)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                Spacer()
                workspaceActions
            }
            headerBar(geometry: geometry)
            MenuContentView(model: model).bannerArea
            if model.accounts.isEmpty {
                Text(model.t(.noAccountsRegistered)).foregroundStyle(.secondary)
            }
            accountsTable
            if let account = accounts.first(where: { $0.id == selection }) {
                ScrollView {
                    NativeAccountDetails(model: model, account: account).id(account.id)
                }.frame(maxHeight: 230)
            }
            Text(String(format: model.t(.accountsCount), accounts.count))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20)
    }

    private func headerBar(geometry: GeometryProxy) -> some View {
        HStack {
            BrandIcon(size: 36)
            Text(model.t(.allTanks)).font(.title2.weight(.semibold))
            Spacer()
            if geometry.size.width < 900 {
                Picker(model.t(.allTanks), selection: $provider) {
                    Text(model.t(.allTanks)).tag("all")
                    ForEach(Provider.allCases) { Text($0.displayName).tag($0.rawValue) }
                }.labelsHidden().frame(width: 150)
            }
            Picker(model.t(.allTanks), selection: $activeOnly) {
                Text(model.t(.allTanks)).tag(false)
                Text(model.t(.allActiveTanks)).tag(true)
            }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 280)
        }
    }

    private var accountsTable: some View {
        Table(accounts, selection: $selection) {
            TableColumn(model.t(.allTanks)) { account in
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.nickname ?? account.email).fontWeight(.medium)
                    Text(account.provider.displayName + " · " + account.email)
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.width(min: 200, ideal: 250)
            TableColumn(model.t(.fiveHourSession)) { account in
                NativeFuelWindow(model: model, window: model.displayUsage(for: account)?.session)
            }.width(min: 120, ideal: 170)
            TableColumn(model.t(.weeklyQuota)) { account in
                NativeFuelWindow(model: model, window: model.displayUsage(for: account)?.weekly)
            }.width(min: 120, ideal: 170)
            TableColumn(model.t(.active)) { account in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t(model.isAccountActive(account) ? .active : .standby))
                    NativeUsageStatus(model: model, usage: model.usage[account.id])
                }.font(.caption)
            }.width(min: 80, ideal: 100)
        }
        .contextMenu(forSelectionType: Account.ID.self) { ids in
            if let id = ids.first, let account = accounts.first(where: { $0.id == id }) {
                Button(model.t(.switchCliAccount)) { model.switchTo(account: account) }
                    .disabled(model.switchingProviders.contains(account.provider))
                Button(model.t(.checkQuotaNow)) { model.refreshAccount(id: id) }
            }
        }
    }

    private var workspaceActions: some View {
        HStack(spacing: 12) {
            Button { model.refreshNow() } label: {
                Label(model.t(.refresh), systemImage: "arrow.clockwise")
            }.disabled(model.isRefreshing).keyboardShortcut("r")
            Menu {
                ForEach(Provider.allCases) { provider in
                    Button(provider.displayName) { model.startLogin(provider: provider) }
                }
            } label: { Label(model.t(.addAccount), systemImage: "plus") }
                .disabled(MenuContentView(model: model).isSigningIn)
            Button { model.showFloatingWidget.toggle() } label: {
                Label(model.t(.hudToggle), systemImage: "macwindow")
            }
            Button { model.openSettings() } label: {
                Label(model.t(.settings), systemImage: "gearshape")
            }.keyboardShortcut(",")
        }
        .labelStyle(.iconOnly)
    }
}
