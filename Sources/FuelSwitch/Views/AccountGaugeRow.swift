import SwiftUI
import FuelSwitchCore

struct AccountGaugeRow: View {
    let window: LimitWindow
    let now: Date
    let paceEnabled: Bool

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
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

        VStack(alignment: .leading, spacing: 3) {
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
}
