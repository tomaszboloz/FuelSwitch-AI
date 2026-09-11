import AppKit
import SwiftUI
import FuelSwitchCore

/// All templates use the same bundled brand asset; never a template-specific logo.
struct BrandIcon: View {
    var size: CGFloat = 28
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: "fuelpump.fill").resizable().foregroundStyle(.orange)
            }
        }
        .scaledToFit().frame(width: size, height: size)
        .accessibilityLabel("FuelSwitch AI")
    }
}

/// A real resizable workspace, backed by exactly the model used by the menu bar.
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
                    List(selection: $provider) {
                        Label(model.t(.allTanks), systemImage: "square.stack").tag("all")
                        ForEach(Provider.allCases) { item in
                            Text(item.displayName).tag(item.rawValue)
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(width: 220)
                    Divider()
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        TextField(model.t(.searchAccounts), text: $search)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                        Spacer()
                        workspaceActions
                    }
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
                    MenuContentView(model: model).bannerArea
                    if model.accounts.isEmpty {
                        Text(model.t(.noAccountsRegistered)).foregroundStyle(.secondary)
                    }
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
                    if let account = accounts.first(where: { $0.id == selection }) {
                        ScrollView {
                            NativeAccountDetails(model: model, account: account).id(account.id)
                        }.frame(maxHeight: 230)
                    }
                    Text(String(format: model.t(.accountsCount), accounts.count))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(model.colorScheme)
        .environment(\.locale, Locale(identifier: model.localization.currentLanguage.rawValue))
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
        .onAppear { model.reloadActiveAccounts() }
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

struct NativeAccountDetails: View {
    @ObservedObject var model: AppModel
    let account: Account
    @State private var confirmingRemoval = false
    @State private var editingName = false
    @State private var nickname = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.nickname ?? account.email).font(.headline)
                    Text(account.email).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { nickname = account.nickname ?? ""; editingName = true } label: {
                    Image(systemName: "pencil")
                }.help(model.t(.editNickname))
                Button(model.t(.checkQuotaNow)) { model.refreshAccount(id: account.id) }
                Button(model.t(.switchCliAccount)) { model.switchTo(account: account) }
                    .disabled(model.switchingProviders.contains(account.provider) || model.isAccountActive(account))
                Button(role: .destructive) { confirmingRemoval = true } label: {
                    Label(model.t(.remove), systemImage: "trash")
                }
            }
            if account.needsReauth {
                Text(model.t(.sessionExpired)).foregroundStyle(.orange)
                Button(model.t(.addAccount)) { model.startLogin(provider: account.provider) }
            }
            NativeUsageStatus(model: model, usage: model.usage[account.id])
            if let usage = model.displayUsage(for: account) {
                HStack(spacing: 20) {
                    ForEach(Array(usage.scoped.enumerated()), id: \.offset) { _, window in
                        VStack(alignment: .leading) {
                            Text(window.label).font(.caption)
                            NativeFuelWindow(model: model, window: window)
                        }
                    }
                }
                if account.provider == .openai, let credits = usage.resetCreditsAvailable, credits > 0 {
                    // Reset redemption is intentionally disabled in AppModel.
                    Text(String(format: model.t(.removeCredit), credits)).font(.caption)
                }
            }
        }
        .confirmationDialog(model.t(.removeConfirm), isPresented: $confirmingRemoval) {
            Button(model.t(.remove), role: .destructive) { model.remove(id: account.id) }
            Button(model.t(.cancel), role: .cancel) {}
        }
        .popover(isPresented: $editingName) {
            VStack(spacing: 12) {
                TextField(account.email, text: $nickname)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(model.t(.cancel)) { editingName = false }
                    Button(model.t(.done)) {
                        model.rename(id: account.id, nickname: nickname)
                        editingName = false
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding().frame(width: 280)
        }
    }
}

struct NativeFuelWindow: View {
    @ObservedObject var model: AppModel
    let window: LimitWindow?
    var showsReset = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let window {
                HStack(spacing: 4) {
                    Text("\(Int(window.remainingPercent))%")
                        .monospacedDigit()
                    if window.isLowFuel {
                        Image(systemName: "fuelpump.fill").foregroundStyle(.orange)
                            .accessibilityLabel(model.t(.lowFuelWarning))
                    }
                }
                ProgressView(value: min(100, window.remainingPercent), total: 100)
                    .tint(window.isLowFuel ? .orange : .accentColor)
                    .accessibilityLabel(model.t(.remainingFuel))
                if showsReset, let reset = window.resetsAt {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        HStack(spacing: 3) {
                            Text(model.t(.resetsIn))
                            Text(reset, style: .relative)
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("—").accessibilityLabel(model.t(.waitingTelemetry))
            }
        }.padding(.vertical, 4)
    }
}

struct NativeUsageStatus: View {
    @ObservedObject var model: AppModel
    let usage: AccountUsage?
    var body: some View {
        Group {
            if let usage {
                switch usage.staleness {
                case .fresh: EmptyView()
                case .cached(let since):
                    Text(String(format: model.t(.cachedTelemetry), ResetFormatter.stringSince(since)))
                        .foregroundStyle(.secondary)
                case .error(let message):
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            } else {
                Text(model.t(.awaitingCheck)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Expanded is a vertical widget; compact is strictly a horizontal bar.
struct NativeWidgetView: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void
    var compactOverride: Bool? = nil
    var showsClose = true
    var compact: Bool { compactOverride ?? (model.widgetStyle == "compact") }

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 12) {
                    BrandIcon(size: 24)
                    ForEach(visibleProviders) { providerRow($0) }
                    controls
                }.padding(.horizontal, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        BrandIcon()
                        Text(model.t(.appName)).font(.headline)
                        Spacer()
                        controls
                    }
                    MenuContentView(model: model).bannerArea
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(visibleProviders) { providerRow($0) }
                            if visibleProviders.isEmpty {
                                Text(model.t(.noAccountsRegistered)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button(model.t(.openMainWindow)) { NativeWindowController.shared.show(model: model) }
                }.padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .preferredColorScheme(model.colorScheme)
        .environment(\.locale, Locale(identifier: model.localization.currentLanguage.rawValue))
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    private var visibleProviders: [Provider] {
        Provider.allCases.filter { provider in model.accounts.contains { $0.provider == provider } }
    }

    private func providerRow(_ provider: Provider) -> some View {
        let account = model.accounts.first { $0.provider == provider && model.isAccountActive($0) }
        let usage = account.flatMap { model.displayUsage(for: $0) }
        return HStack(spacing: 10) {
            Menu {
                ForEach(model.accounts.filter { $0.provider == provider }) { item in
                    Button((model.isAccountActive(item) ? "✓ " : "") + (item.nickname ?? item.email)) {
                        model.switchTo(account: item)
                    }.disabled(model.switchingProviders.contains(provider))
                }
                Divider()
                Button(model.t(.addAccount)) { model.startLogin(provider: provider) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName).fontWeight(.semibold)
                    if !compact {
                        Text(account?.nickname ?? account?.email ?? model.t(.noActiveCliAccount))
                            .font(.caption).lineLimit(1)
                        NativeUsageStatus(model: model, usage: account.flatMap { model.usage[$0.id] })
                            .font(.caption2).lineLimit(2)
                    }
                }
            }.menuStyle(.borderlessButton).fixedSize(horizontal: compact, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t(.fiveHourSession)).font(.caption2).lineLimit(1)
                NativeFuelWindow(model: model, window: usage?.session, showsReset: !compact)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t(.weeklyQuota)).font(.caption2).lineLimit(1)
                NativeFuelWindow(model: model, window: usage?.weekly, showsReset: !compact)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if compactOverride == nil {
                Button { model.widgetStyle = compact ? "expanded" : "compact" } label: {
                    Image(systemName: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                }.help(model.t(compact ? .hudExpanded : .hudCompact))
            }
            Button { model.openSettings() } label: { Image(systemName: "gearshape") }
                .help(model.t(.settings))
            if showsClose {
                Button(action: onClose) { Image(systemName: "xmark") }.help(model.t(.dismiss))
            }
        }.buttonStyle(.borderless)
    }
}
