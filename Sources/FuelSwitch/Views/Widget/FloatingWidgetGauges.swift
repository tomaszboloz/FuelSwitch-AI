import SwiftUI
import FuelSwitchCore

struct FloatingWidgetGauges: View {
    @ObservedObject var model: AppModel
    let usage: AccountUsage?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            if let usage {
                VStack(spacing: 5) {
                    gaugeItem(title: model.t(.fiveHourSession), window: usage.session, now: context.date)
                    gaugeItem(title: model.t(.weeklyQuota), window: usage.weekly, now: context.date)
                }
            } else {
                Text(model.t(.waitingTelemetry))
                    .font(.system(size: 9.5))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private func gaugeItem(title: String, window: LimitWindow, now: Date) -> some View {
        let remaining = max(0, min(100, 100.0 - window.percent))
        let isLow = remaining < 20.0
        let resetText = window.resetsAt.map {
            title == model.t(.fiveHourSession)
                ? ResetFormatter.string(for: $0, now: now, includeSeconds: true)
                : ResetFormatter.string(for: $0, now: now)
        }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                if isLow {
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.amber)
                }
                Spacer()
                if let resetText {
                    HStack(spacing: 2) {
                        Image(systemName: "clock").font(.system(size: 7))
                        Text(resetText).font(.system(size: 8.5).monospacedDigit())
                    }
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                }
                Text("\(Int(remaining))%")
                    .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: window.percent))
            }
            FuelGauge(
                value: remaining,
                color: FuelSwitchTheme.fuelColor(percentUsed: window.percent),
                height: 4,
                showSegments: false
            )
        }
    }
}
