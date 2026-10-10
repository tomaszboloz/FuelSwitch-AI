import SwiftUI
import FuelSwitchCore

struct FloatingWidgetCard: View {
    @ObservedObject var model: AppModel
    let account: Account
    let accountsForProvider: [Account]

    var body: some View {
        let usage = account.needsReauth ? nil : model.usage[account.id]
        let isActiveInCLI = model.isAccountActive(account)

        return VStack(alignment: .leading, spacing: 7) {
            headerRow(isActiveInCLI: isActiveInCLI, usage: usage)
            resetsRow(usage: usage)
            FloatingWidgetGauges(model: model, usage: usage)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isActiveInCLI ? FuelSwitchTheme.bgCard : FuelSwitchTheme.bgCard.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isActiveInCLI ? FuelSwitchTheme.amber.opacity(0.4) : FuelSwitchTheme.borderSubtle.opacity(0.5), lineWidth: isActiveInCLI ? 1.2 : 0.8))
    }

    private func headerRow(isActiveInCLI: Bool, usage: AccountUsage?) -> some View {
        HStack(spacing: 6) {
            Text(account.provider.monogram).font(.system(size: 8.5, weight: .heavy))
                .padding(.horizontal, 4.5).padding(.vertical, 2)
                .background(isActiveInCLI ? FuelSwitchTheme.amber.opacity(0.25) : Color.white.opacity(0.08))
                .foregroundStyle(isActiveInCLI ? FuelSwitchTheme.amber : FuelSwitchTheme.textTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 1) {
                Text(account.email).font(.system(size: 11, weight: isActiveInCLI ? .bold : .semibold))
                    .foregroundStyle(isActiveInCLI ? FuelSwitchTheme.textPrimary : FuelSwitchTheme.textSecondary)
                    .lineLimit(1).truncationMode(.middle)
                if let plan = account.plan {
                    Text(plan.uppercased()).font(.system(size: 7.5, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }

            Spacer()

            if let usage, usage.isLowFuel {
                LowFuelIndicator(size: 9, showText: true, text: LocalizationManager.shared.text(.lowFuelWarningShort))
            }

            statusButtons(isActiveInCLI: isActiveInCLI)
            switcherDropdown
        }
    }

    @ViewBuilder
    private func statusButtons(isActiveInCLI: Bool) -> some View {
        if model.requiresAntigravityLogin(account) {
            Button(model.t(.reauthenticate) + " — Antigravity") { model.switchTo(account: account) }
                .buttonStyle(.plain).font(.system(size: 8, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
        } else if account.needsReauth {
            Button { model.startLogin(provider: account.provider) } label: {
                HStack(spacing: 3) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark").font(.system(size: 7.5, weight: .bold))
                    Text(model.t(.reauthenticate)).font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(FuelSwitchTheme.amber.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(FuelSwitchTheme.amber.opacity(0.4), lineWidth: 0.8))
                .foregroundStyle(FuelSwitchTheme.amber)
            }
            .buttonStyle(.plain).help(model.t(.reauthenticate))
        } else if isActiveInCLI {
            HStack(spacing: 3) {
                Circle().fill(FuelSwitchTheme.emerald).frame(width: 5, height: 5)
                Text(model.t(.active)).font(.system(size: 8, weight: .heavy)).foregroundStyle(FuelSwitchTheme.emerald)
            }
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(FuelSwitchTheme.emerald.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Button(model.t(.engage)) { model.switchTo(account: account) }
                .buttonStyle(.plain).font(.system(size: 8.5, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(FuelSwitchTheme.amber.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8))
                .foregroundStyle(FuelSwitchTheme.amber)
        }
    }

    @ViewBuilder
    private var switcherDropdown: some View {
        if accountsForProvider.count > 1 {
            Menu {
                Text(model.t(.switchTank) + ":")
                ForEach(accountsForProvider) { candidate in
                    Button {
                        if candidate.needsReauth { model.startLogin(provider: candidate.provider) }
                        else { model.switchTo(account: candidate) }
                    } label: {
                        HStack {
                            Text(candidate.email + (candidate.needsReauth ? " — " + model.t(.reauthenticate) : ""))
                            if model.isAccountActive(candidate) { Text("✓ " + model.t(.active)) }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(FuelSwitchTheme.amber).padding(4)
            }
            .menuStyle(.borderlessButton).fixedSize()
        }
    }

    @ViewBuilder
    private func resetsRow(usage: AccountUsage?) -> some View {
        if account.provider == .openai, (usage?.resetCreditsAvailable ?? 0) > 0 {
            let credits = usage?.resetCreditsAvailable ?? 0
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.badge.clock.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                    Text(String(format: model.t(.removeCredit), credits)).font(.system(size: 8.5, weight: .heavy).monospacedDigit()).foregroundStyle(FuelSwitchTheme.amber)
                }
                .padding(.horizontal, 4).padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 3).fill(FuelSwitchTheme.amber.opacity(0.15)))
                Spacer()
                Button { model.redeemCodexReset(account: account) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise.circle.fill").font(.system(size: 7.5, weight: .bold))
                        Text(model.t(.resetLimit)).font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(FuelSwitchTheme.emerald.opacity(0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(FuelSwitchTheme.emerald.opacity(0.4), lineWidth: 0.8))
                    .foregroundStyle(FuelSwitchTheme.emerald)
                }
                .buttonStyle(.plain).help(model.t(.redeemResetHelp)).disabled(model.isResetting(account))
            }
        } else if account.provider == .anthropic {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                Text(model.t(.openClaudeReset)).font(.system(size: 8, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                Spacer()
                Button { model.openClaudeLimitReset(account: account) } label: {
                    Text(model.t(.resetLimit)).font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(FuelSwitchTheme.amber.opacity(0.16)))
                        .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain).help(model.t(.claudeResetHelp))
            }
        }
    }
}
