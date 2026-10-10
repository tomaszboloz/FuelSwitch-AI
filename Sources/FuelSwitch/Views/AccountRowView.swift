import SwiftUI
import FuelSwitchCore

/// Redesigned FuelSwitch AI Account Card.
struct AccountRowView: View {
    let account: Account
    let usage: AccountUsage?
    let isActive: Bool
    let onSwitch: () -> Void
    let refresh: () -> Void
    let remove: () -> Void
    var onRedeemReset: (() -> Void)? = nil
    var onClaudeReset: (() -> Void)? = nil
    var onReauthenticate: (() -> Void)? = nil
    var paceEnabled: Bool = false
    var onRename: ((String?) -> Void)? = nil

    @State private var confirmingRemoval = false
    @State private var isHovered = false
    @State private var isEditingNickname = false
    @State private var nicknameDraft = ""

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let exhausted = isExhausted(at: now)

            VStack(alignment: .leading, spacing: 8) {
                AccountRowHeader(
                    account: account, usage: usage, isActive: isActive, exhausted: exhausted,
                    isEditingNickname: $isEditingNickname, nicknameDraft: $nicknameDraft,
                    confirmingRemoval: $confirmingRemoval, onSwitch: onSwitch, refresh: refresh,
                    onRename: onRename, commitNickname: commitNickname
                )

                if confirmingRemoval {
                    inlineRemovalPrompt
                } else {
                    AccountRowActions(
                        account: account, usage: usage, onRedeemReset: onRedeemReset,
                        onClaudeReset: onClaudeReset, onReauthenticate: onReauthenticate,
                        confirmingRemoval: confirmingRemoval
                    )

                    ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                        AccountGaugeRow(window: window, now: now, paceEnabled: paceEnabled)
                    }

                    if let note {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle").font(.system(size: 9))
                            Text(note).font(.system(size: 9.5)).lineLimit(2)
                        }
                        .foregroundStyle(account.needsReauth ? FuelSwitchTheme.amber : FuelSwitchTheme.textTertiary)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9).fill(cardBackgroundColor(isActive: isActive, exhausted: exhausted)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(cardBorderColor(isActive: isActive, exhausted: exhausted), lineWidth: 1))
            .onHover { isHovered = $0 }
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .contextMenu {
                Button(loc.text(.switchCliAccount)) { onSwitch() }
                Divider()
                Button(loc.text(.checkQuotaNow)) { refresh() }
                Button(loc.text(.removeAccount)) { confirmingRemoval = true }
            }
        }
    }

    private var inlineRemovalPrompt: some View {
        HStack(spacing: 8) {
            Text(loc.text(.removeThisAccount)).font(.system(size: 10.5, weight: .medium)).foregroundStyle(FuelSwitchTheme.textSecondary)
            Spacer()
            Button(loc.text(.cancel)) { confirmingRemoval = false }
                .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(FuelSwitchTheme.textTertiary)
            Button(loc.text(.remove)) { remove() }
                .buttonStyle(.plain).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.crimson)
        }
        .padding(.vertical, 4)
    }

    private func commitNickname() {
        isEditingNickname = false
        onRename?(nicknameDraft)
    }

    private func isExhausted(at now: Date) -> Bool {
        if account.needsReauth { return true }
        return windows.contains { window in
            guard window.percent >= 100 else { return false }
            if let resetsAt = window.resetsAt, resetsAt <= now { return false }
            return true
        }
    }

    private func cardBackgroundColor(isActive: Bool, exhausted: Bool) -> Color {
        if exhausted { return FuelSwitchTheme.crimson.opacity(0.08) }
        if isActive { return FuelSwitchTheme.amber.opacity(0.07) }
        return isHovered ? FuelSwitchTheme.bgCardHover : FuelSwitchTheme.bgCard
    }

    private func cardBorderColor(isActive: Bool, exhausted: Bool) -> Color {
        if exhausted { return FuelSwitchTheme.crimson.opacity(0.35) }
        if isActive { return FuelSwitchTheme.amber.opacity(0.40) }
        return isHovered ? FuelSwitchTheme.borderRegular : FuelSwitchTheme.borderSubtle
    }

    private var windows: [LimitWindow] {
        guard !account.needsReauth, let usage else { return [] }
        if case .error = usage.staleness { return [] }
        if account.provider == .gemini { return [usage.session, usage.weekly] }
        return [usage.session, usage.weekly] + usage.scoped
    }

    private var note: String? {
        if account.needsReauth { return loc.text(.sessionExpired) }
        guard let usage else { return loc.text(.awaitingCheck) }
        if case .error(let description) = usage.staleness { return description }
        if case .cached(let since) = usage.staleness {
            return String(format: loc.text(.cachedTelemetry), ResetFormatter.stringSince(since))
        }
        return nil
    }
}
