import SwiftUI
import FuelSwitchCore

struct AccountRowActions: View {
    let account: Account
    let usage: AccountUsage?
    var onRedeemReset: (() -> Void)?
    var onClaudeReset: (() -> Void)?
    var onReauthenticate: (() -> Void)?
    let confirmingRemoval: Bool

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        VStack(spacing: 4) {
            reauthRow
            codexResetRow
            claudeResetRow
        }
    }

    @ViewBuilder
    private var reauthRow: some View {
        if account.needsReauth, let onReauthenticate {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                Text(loc.text(.sessionExpired))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(FuelSwitchTheme.amber)
                Spacer()
                Button(action: onReauthenticate) {
                    Text(loc.text(.reauthenticate))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(FuelSwitchTheme.amber.opacity(0.16)))
                        .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain).help(loc.text(.reauthenticate)).disabled(confirmingRemoval)
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var codexResetRow: some View {
        if account.provider == .openai, (usage?.resetCreditsAvailable ?? 0) > 0 {
            let credits = usage?.resetCreditsAvailable ?? 0
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.badge.clock.fill")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                    Text(String(format: loc.text(.removeCredit), credits))
                        .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                        .foregroundStyle(FuelSwitchTheme.amber)
                }
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(FuelSwitchTheme.amber.opacity(0.15)))
                Spacer()
                if let onRedeemReset {
                    Button(action: onRedeemReset) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(loc.text(.resetLimit)).font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(FuelSwitchTheme.emerald.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(FuelSwitchTheme.emerald.opacity(0.4), lineWidth: 0.8))
                        .foregroundStyle(FuelSwitchTheme.emerald)
                    }
                    .buttonStyle(.plain).help(loc.text(.redeemResetHelp)).disabled(confirmingRemoval)
                }
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var claudeResetRow: some View {
        if account.provider == .anthropic, let onClaudeReset {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                Text(loc.text(.openClaudeReset))
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                Spacer()
                Button(action: onClaudeReset) {
                    Text(loc.text(.resetLimit))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2.5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(FuelSwitchTheme.amber.opacity(0.16)))
                        .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain).help(loc.text(.claudeResetHelp)).disabled(confirmingRemoval)
            }
            .padding(.vertical, 1)
        }
    }
}
