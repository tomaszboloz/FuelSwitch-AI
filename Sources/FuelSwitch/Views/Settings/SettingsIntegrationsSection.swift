import SwiftUI
import FuelSwitchCore

struct SettingsIntegrationsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            heatmapCard
            sparkleCard
        }
    }

    private var heatmapCard: some View {
        SettingsCard(title: model.t(.usageHeatmapTitle), icon: "square.grid.3x3.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(model.t(.usageHeatmapToggle))
                        .font(.system(size: 11))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Toggle("", isOn: $model.usageHeatmapEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Text(model.t(.usageHeatmapExplanation))
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                if model.usageHeatmapEnabled {
                    UsageHeatmapView(
                        days: model.usageHeatmapDays,
                        isLoading: model.usageHeatmapIsLoading,
                        loadingText: model.t(.usageHeatmapLoading),
                        emptyText: model.t(.usageHeatmapEmpty),
                        summarySuffix: model.t(.usageHeatmapSummarySuffix)
                    )
                }
            }
        }
    }

    private var sparkleCard: some View {
        SettingsCard(title: model.t(.sparkleUpdatesTitle), icon: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(model.t(.sparkleAutoCheckToggle))
                        .font(.system(size: 11))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Toggle("", isOn: $model.sparkleAutoCheckEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(model.t(.sparkleAutoDownloadToggle))
                        .font(.system(size: 11))
                        .foregroundStyle(model.sparkleAutoCheckEnabled ? FuelSwitchTheme.textPrimary : FuelSwitchTheme.textTertiary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Toggle("", isOn: $model.sparkleAutoDownloadEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!model.sparkleAutoCheckEnabled)
                }

                Text(model.t(.sparkleExplanation))
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
