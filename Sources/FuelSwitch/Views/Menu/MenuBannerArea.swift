import SwiftUI
import FuelSwitchCore

struct MenuBannerArea: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            resetBanner
            updateBanner
            loginStateBanner
        }
    }

    @ViewBuilder
    private var resetBanner: some View {
        if let resetResult = model.resetResult {
            switch resetResult {
            case .completed(let email):
                bannerRow(text: String(format: model.t(.resetCompleted), email), tint: FuelSwitchTheme.emerald) {
                    Button(model.t(.dismiss)) { model.dismissResetResult() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            case .failed(let message):
                bannerRow(text: message, tint: FuelSwitchTheme.crimson) {
                    Button(model.t(.dismiss)) { model.dismissResetResult() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var updateBanner: some View {
        if let update = model.availableUpdate {
            bannerRow(text: String(format: model.t(.versionAvailable), update.version), tint: FuelSwitchTheme.amber) {
                HStack(spacing: 8) {
                    Button(model.t(.download)) { model.openUpdate() }
                        .buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                    Button(model.t(.dismiss)) { model.dismissUpdate() }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private var loginStateBanner: some View {
        switch model.loginState {
        case .idle:
            EmptyView()
        case .running(let provider):
            bannerRow(text: String(format: model.t(.connecting), provider.displayName), tint: FuelSwitchTheme.amber) {
                Button(model.t(.cancel)) { model.cancelLogin() }
                    .buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.crimson)
            }
        case .failed(_, let message):
            bannerRow(text: message, tint: FuelSwitchTheme.amber) {
                HStack {
                    if let account = model.antigravityLoginAccount {
                        Button(model.t(.reauthenticate) + " — Antigravity") { model.openAntigravityLogin() }
                            .help(account.email)
                        Button(model.t(.switchCliAccount)) { model.switchTo(account: account) }
                    }
                    Button(model.t(.dismiss)) { model.dismissLoginState() }
                }
                .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.amber)
            }
        case .added(let email):
            bannerRow(text: String(format: model.t(.connected), email), tint: FuelSwitchTheme.emerald) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .reconnected(let email):
            bannerRow(text: String(format: model.t(.reconnected), email), tint: FuelSwitchTheme.amber) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .switched(let provider, let email):
            bannerRow(text: String(format: model.t(.switched), provider.displayName, email), tint: FuelSwitchTheme.emerald) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        case .autoSwitched(let provider, let from, let to):
            bannerRow(text: String(format: model.t(.autoSwitchedBanner), provider.displayName, from, to), tint: FuelSwitchTheme.amber) {
                Button(model.t(.dismiss)) { model.dismissLoginState() }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private func bannerRow(text: String, tint: Color, @ViewBuilder action: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(text).font(.system(size: 10.5, weight: .medium)).foregroundStyle(tint).lineLimit(2)
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(tint.opacity(0.08))
    }
}
