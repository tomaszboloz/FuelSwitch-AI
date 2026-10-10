import SwiftUI
import FuelSwitchCore

struct AccountRowHeader: View {
    let account: Account
    let usage: AccountUsage?
    let isActive: Bool
    let exhausted: Bool
    @Binding var isEditingNickname: Bool
    @Binding var nicknameDraft: String
    @Binding var confirmingRemoval: Bool
    let onSwitch: () -> Void
    let refresh: () -> Void
    let onRename: ((String?) -> Void)?
    let commitNickname: () -> Void

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            providerIcon
            identitySection
            Spacer(minLength: 4)
            badgesSection
            actionsSection
        }
    }

    private var providerIcon: some View {
        let (color, icon): (Color, String) = {
            switch account.provider {
            case .anthropic: return (Color(red: 0.95, green: 0.60, blue: 0.40), "sparkles")
            case .openai: return (Color(red: 0.30, green: 0.85, blue: 0.70), "terminal.fill")
            case .gemini: return (Color(red: 0.35, green: 0.65, blue: 0.98), "diamond.fill")
            }
        }()
        return ZStack {
            RoundedRectangle(cornerRadius: 5).fill(color.opacity(0.18)).frame(width: 22, height: 22)
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 1) {
            if isEditingNickname {
                TextField(account.email, text: $nicknameDraft, onCommit: commitNickname)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: isActive ? .bold : .semibold))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                    .onExitCommand { isEditingNickname = false }
            } else {
                Text(account.nickname ?? account.email)
                    .font(.system(size: 12, weight: isActive ? .bold : .semibold))
                    .foregroundStyle(exhausted ? FuelSwitchTheme.crimson : FuelSwitchTheme.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                    .onTapGesture(count: 2) {
                        guard onRename != nil else { return }
                        nicknameDraft = account.nickname ?? ""
                        isEditingNickname = true
                    }
                    .help(onRename != nil ? account.email : "")
            }
            if let plan = account.plan {
                Text(plan.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private var badgesSection: some View {
        Group {
            if let usage, usage.isLowFuel && !exhausted && !account.needsReauth {
                LowFuelIndicator(size: 10, showText: true, text: loc.text(.lowFuelWarningShort))
            }
            if account.needsReauth {
                FuelBadge(type: .reauth, title: loc.text(.sessionExpired))
            } else if isActive {
                FuelBadge(type: .active, title: loc.text(.active))
            } else if exhausted {
                FuelBadge(type: .exhausted, title: loc.text(.lowFuelWarningShort))
            }
        }
    }

    private var actionsSection: some View {
        HStack(spacing: 6) {
            if !isActive && !account.needsReauth {
                Button(action: onSwitch) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 8.5))
                        Text(loc.text(.engage)).font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(FuelSwitchTheme.amber.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8))
                    .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain).help(loc.text(.switchCliAccount)).disabled(confirmingRemoval)
            }
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise").font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
            .buttonStyle(.plain).help(loc.text(.checkQuotaNow)).disabled(confirmingRemoval)
            Button { confirmingRemoval = true } label: {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
            .buttonStyle(.plain).help(loc.text(.removeAccount)).disabled(confirmingRemoval)
        }
    }
}
