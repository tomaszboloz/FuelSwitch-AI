import SwiftUI
import FuelSwitchCore

struct NativeAccountDetails: View {
    @ObservedObject var model: AppModel
    let account: Account
    @State private var confirmingRemoval = false
    @State private var editingName = false
    @State private var nickname = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            headerRow
            statusSection
            usageSection
        }
        .confirmationDialog(model.t(.removeConfirm), isPresented: $confirmingRemoval) {
            Button(model.t(.remove), role: .destructive) { model.remove(id: account.id) }
            Button(model.t(.cancel), role: .cancel) {}
        }
        .popover(isPresented: $editingName) {
            renamePopover
        }
    }

    private var headerRow: some View {
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
            if account.provider == .anthropic {
                Button(model.t(.resetLimit)) { model.openClaudeLimitReset(account: account) }
                    .help(model.t(.claudeResetHelp))
            }
        }
    }

    private var statusSection: some View {
        Group {
            if model.requiresAntigravityLogin(account) {
                Button(model.t(.reauthenticate) + " — Antigravity") { model.switchTo(account: account) }
            }
            if account.needsReauth {
                Text(model.t(.sessionExpired)).foregroundStyle(.orange)
                Button(model.t(.reauthenticate)) { model.startLogin(provider: account.provider) }
            }
            NativeUsageStatus(model: model, usage: model.usage[account.id])
        }
    }

    private var usageSection: some View {
        Group {
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
                    HStack(spacing: 8) {
                        Text(String(format: model.t(.removeCredit), credits)).font(.caption)
                        Button(model.t(.resetLimit)) { model.redeemCodexReset(account: account) }
                            .disabled(model.isResetting(account))
                            .help(model.t(.redeemResetHelp))
                    }
                }
            }
        }
    }

    private var renamePopover: some View {
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
