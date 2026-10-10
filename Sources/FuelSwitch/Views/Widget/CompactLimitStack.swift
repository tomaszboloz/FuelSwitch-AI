import SwiftUI
import FuelSwitchCore

struct CompactLimitStack: View {
    let prefix: String
    let window: LimitWindow
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Text(prefix)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                Text("\(Int(window.remainingPercent))%")
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: window.percent))
            }
            if let resetsAt = window.resetsAt {
                Text(ResetFormatter.string(for: resetsAt, now: now))
                    .font(.system(size: 7, weight: .medium).monospacedDigit())
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }
}
