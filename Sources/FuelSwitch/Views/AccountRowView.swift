import SwiftUI
import FuelSwitchCore

/// Redesigned FuelSwitch AI Account Card.
/// Combines high-density telemetry with a distinctive command-deck aesthetic.
struct AccountRowView: View {
    let account: Account
    let usage: AccountUsage?
    let isActive: Bool
    let onSwitch: () -> Void
    let refresh: () -> Void
    let remove: () -> Void
    var onRedeemReset: (() -> Void)? = nil
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
                // Card Header: Identity, Status Badge, Quick Switcher Action
                HStack(alignment: .center, spacing: 6) {
                    // Provider Icon Pill
                    ZStack {
                        let iconColor: Color = {
                            switch account.provider {
                            case .anthropic: return Color(red: 0.95, green: 0.60, blue: 0.40)
                            case .openai: return Color(red: 0.30, green: 0.85, blue: 0.70)
                            case .gemini: return Color(red: 0.35, green: 0.65, blue: 0.98)
                            }
                        }()
                        let iconName: String = {
                            switch account.provider {
                            case .anthropic: return "sparkles"
                            case .openai: return "terminal.fill"
                            case .gemini: return "diamond.fill"
                            }
                        }()

                        RoundedRectangle(cornerRadius: 5)
                            .fill(iconColor.opacity(0.18))
                            .frame(width: 22, height: 22)

                        Image(systemName: iconName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(iconColor)
                    }

                    // Account Nickname/Email & Plan
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
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .onTapGesture(count: 2) {
                                    guard onRename != nil else { return }
                                    nicknameDraft = account.nickname ?? ""
                                    isEditingNickname = true
                                }
                                .help(onRename != nil ? account.email : "")
                        }

                        if let plan = account.plan {
                            Text(plan.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(FuelSwitchTheme.textTertiary)
                        }
                    }

                    Spacer(minLength: 4)

                    // Low Fuel Warning & Status Badges
                    if let usage, usage.isLowFuel && !exhausted && !account.needsReauth {
                        LowFuelIndicator(size: 10, showText: true, text: loc.text(.lowFuelWarningShort))
                    }

                    if isActive {
                        FuelBadge(type: .active, title: loc.text(.active))
                    } else if exhausted {
                        FuelBadge(type: .exhausted, title: loc.text(.lowFuelWarningShort))
                    } else if account.needsReauth {
                        FuelBadge(type: .reauth, title: loc.text(.sessionExpired))
                    }

                    // 1-Click CLI Switcher Action Button
                    if !isActive && !account.needsReauth {
                        Button(action: onSwitch) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 8.5))
                                Text(loc.text(.engage))
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(FuelSwitchTheme.amber.opacity(0.14))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8)
                            )
                            .foregroundStyle(FuelSwitchTheme.amber)
                        }
                        .buttonStyle(.plain)
                        .help(loc.text(.switchCliAccount))
                        .disabled(confirmingRemoval)
                    }

                    // Account Refresh
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(FuelSwitchTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(loc.text(.checkQuotaNow))
                    .disabled(confirmingRemoval)

                    // Removal Trigger
                    Button { confirmingRemoval = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(FuelSwitchTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help(loc.text(.removeAccount))
                    .disabled(confirmingRemoval)
                }

                // Inline Removal Confirmation
                if confirmingRemoval {
                    inlineRemovalPrompt
                } else {
                    // OpenAI Codex Reset Credit indicator & action - always visible for Codex
                    if account.provider == .openai {
                        let credits = max(1, usage?.resetCreditsAvailable ?? 1)
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.badge.clock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(FuelSwitchTheme.amber)
                                Text(String(format: loc.text(.removeCredit), credits))
                                    .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                                    .foregroundStyle(FuelSwitchTheme.amber)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(FuelSwitchTheme.amber.opacity(0.15)))

                            Spacer()

                            if let onRedeemReset {
                                Button(action: onRedeemReset) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                            .font(.system(size: 8.5, weight: .bold))
                                        Text(loc.text(.resetLimit))
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(FuelSwitchTheme.emerald.opacity(0.18))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(FuelSwitchTheme.emerald.opacity(0.4), lineWidth: 0.8)
                                    )
                                    .foregroundStyle(FuelSwitchTheme.emerald)
                                }
                                .buttonStyle(.plain)
                                .help(loc.text(.redeemResetHelp))
                            }
                        }
                        .padding(.vertical, 1)
                    }

                    // Fuel Gauges for all windows
                    ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                        windowGaugeRow(window: window, now: now)
                    }

                    if let note {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 9))
                            Text(note)
                                .font(.system(size: 9.5))
                                .lineLimit(2)
                        }
                        .foregroundStyle(account.needsReauth ? FuelSwitchTheme.amber : FuelSwitchTheme.textTertiary)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(cardBackgroundColor(isActive: isActive, exhausted: exhausted))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(cardBorderColor(isActive: isActive, exhausted: exhausted), lineWidth: 1)
            )
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

    // MARK: - Window Gauge Row
    private func windowGaugeRow(window: LimitWindow, now: Date) -> some View {
        let isResetPassed = window.resetsAt.map { $0 <= now } ?? false
        let remainingFuel = max(0, min(100, 100.0 - window.percent))
        let isWindowLow = remainingFuel < 20.0 && !isResetPassed
        let color = FuelSwitchTheme.fuelColor(percentUsed: window.percent, isResetPassed: isResetPassed)
        let pace: PaceEstimate? = paceEnabled && !isResetPassed
            ? PaceEstimator.estimate(
                window: window,
                windowDuration: window.label == "5 hours" ? PaceEstimator.sessionWindowDuration : PaceEstimator.weeklyWindowDuration,
                now: now
            )
            : nil

        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    Text(window.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FuelSwitchTheme.textSecondary)

                    if isWindowLow {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(FuelSwitchTheme.amber)
                            .help(loc.text(.lowFuelWarning))
                    }

                    if let pace, pace.tier != .onPace {
                        Image(systemName: pace.tier == .burningFast ? "hare.fill" : "tortoise.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(pace.tier == .burningFast ? FuelSwitchTheme.crimson : FuelSwitchTheme.emerald)
                    }
                }

                Spacer()

                if let resetsAt = window.resetsAt {
                    let resetText = window.label == "5 hours"
                        ? ResetFormatter.string(for: resetsAt, now: now, includeSeconds: true)
                        : ResetFormatter.string(for: resetsAt, now: now)

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(resetText)
                            .font(.system(size: 9.5).monospacedDigit())
                    }
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                }

                Text("\(Int(remainingFuel))%")
                    .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .frame(width: 36, alignment: .trailing)
            }

            FuelGauge(value: remainingFuel, color: color, height: 5)
        }
    }

    // MARK: - Inline Removal
    private var inlineRemovalPrompt: some View {
        HStack(spacing: 8) {
            Text(loc.text(.removeThisAccount))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(FuelSwitchTheme.textSecondary)
            Spacer()
            Button(loc.text(.cancel)) { confirmingRemoval = false }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(FuelSwitchTheme.textTertiary)
            Button(loc.text(.remove)) { remove() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FuelSwitchTheme.crimson)
        }
        .padding(.vertical, 4)
    }

    private func commitNickname() {
        isEditingNickname = false
        onRename?(nicknameDraft)
    }

    // MARK: - Helpers & Styling
    private func isExhausted(at now: Date) -> Bool {
        if account.needsReauth { return true }
        return windows.contains { window in
            guard window.percent >= 100 else { return false }
            if let resetsAt = window.resetsAt, resetsAt <= now { return false }
            return true
        }
    }

    private func cardBackgroundColor(isActive: Bool, exhausted: Bool) -> Color {
        if exhausted {
            return FuelSwitchTheme.crimson.opacity(0.08)
        } else if isActive {
            return FuelSwitchTheme.amber.opacity(0.07)
        } else if isHovered {
            return FuelSwitchTheme.bgCardHover
        } else {
            return FuelSwitchTheme.bgCard
        }
    }

    private func cardBorderColor(isActive: Bool, exhausted: Bool) -> Color {
        if exhausted {
            return FuelSwitchTheme.crimson.opacity(0.35)
        } else if isActive {
            return FuelSwitchTheme.amber.opacity(0.40)
        } else if isHovered {
            return FuelSwitchTheme.borderRegular
        } else {
            return FuelSwitchTheme.borderSubtle
        }
    }

    private var windows: [LimitWindow] {
        guard !account.needsReauth, let usage else { return [] }
        if case .error = usage.staleness { return [] }
        if account.provider == .gemini {
            return [usage.session, usage.weekly]
        }
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
