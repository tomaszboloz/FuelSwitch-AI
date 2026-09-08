import SwiftUI
import FuelSwitchCore

struct UsageHeatmapView: View {
    let days: [DailyTokenUsage]
    let isLoading: Bool
    let loadingText: String
    let emptyText: String
    let summarySuffix: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 15)

    private var maxTokens: Int {
        days.map(\.totalTokens).max() ?? 0
    }

    private var totalTokens: Int {
        days.reduce(0) { $0 + $1.totalTokens }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                Text(loadingText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            } else if days.allSatisfy({ $0.totalTokens == 0 }) {
                Text(emptyText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(days) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(FuelSwitchTheme.amber.opacity(intensity(for: day.totalTokens)))
                            .frame(height: 12)
                            .help(tooltip(for: day))
                    }
                }

                Text("\(totalTokens.formatted()) \(summarySuffix)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
            }
        }
    }

    private func intensity(for tokens: Int) -> Double {
        guard maxTokens > 0, tokens > 0 else { return 0.08 }
        return 0.15 + 0.85 * (Double(tokens) / Double(maxTokens))
    }

    private func tooltip(for day: DailyTokenUsage) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: day.date)): \(day.totalTokens.formatted())"
    }
}
