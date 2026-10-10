import SwiftUI
import FuelSwitchCore

/// Expanded is a vertical widget; compact is strictly a horizontal bar.
struct NativeWidgetView: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void
    var compactOverride: Bool? = nil
    var showsClose = true
    var allowsWindowDragging = true
    var compact: Bool { compactOverride ?? (model.widgetStyle == "compact") }

    var body: some View {
        ZStack {
            if allowsWindowDragging {
                WidgetDragHandle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }

            Group {
                if compact {
                    HStack(spacing: 12) {
                        BrandIcon(size: 24)
                            .overlay(allowsWindowDragging ? WidgetDragHandle().accessibilityHidden(true) : nil)
                        ForEach(visibleProviders) { providerRow($0) }
                        controls
                    }.padding(.horizontal, 12)
                } else {
                    expandedContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .preferredColorScheme(model.colorScheme)
        .environment(\.locale, Locale(identifier: model.localization.currentLanguage.rawValue))
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BrandIcon()
                    .overlay(allowsWindowDragging ? WidgetDragHandle().accessibilityHidden(true) : nil)
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
        }
        .padding(16)
    }

    private var visibleProviders: [Provider] {
        Provider.allCases.filter { provider in model.accounts.contains { $0.provider == provider } }
    }

    private func providerRow(_ provider: Provider) -> some View {
        let account = model.accounts.first { $0.provider == provider && model.isAccountActive($0) }
            ?? model.accounts.first { $0.provider == provider }
        let usage = account.flatMap { model.displayUsage(for: $0) }
        return HStack(spacing: 10) {
            providerMenu(provider: provider, account: account)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t(.fiveHourSession)).font(.caption2).lineLimit(1)
                NativeFuelWindow(model: model, window: usage?.session, showsReset: !compact)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(model.t(.weeklyQuota)).font(.caption2).lineLimit(1)
                NativeFuelWindow(model: model, window: usage?.weekly, showsReset: !compact)
            }
            accountActionButtons(account: account)
        }
    }

    private func providerMenu(provider: Provider, account: Account?) -> some View {
        Menu {
            ForEach(model.accounts.filter { $0.provider == provider }) { item in
                Button((model.isAccountActive(item) ? "✓ " : "") + (item.nickname ?? item.email)
                       + (item.needsReauth ? " — " + model.t(.reauthenticate) : "")) {
                    if item.needsReauth {
                        model.startLogin(provider: item.provider)
                    } else {
                        model.switchTo(account: item)
                    }
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
    }

    @ViewBuilder
    private func accountActionButtons(account: Account?) -> some View {
        if let account, account.needsReauth {
            Button { model.startLogin(provider: account.provider) } label: {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
            }
            .buttonStyle(.borderless)
            .help(model.t(.reauthenticate))
        } else if let account, account.provider == .anthropic {
            Button { model.openClaudeLimitReset(account: account) } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
            }
            .buttonStyle(.borderless)
            .help(model.t(.claudeResetHelp))
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
