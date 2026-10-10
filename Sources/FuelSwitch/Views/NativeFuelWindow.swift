import SwiftUI
import FuelSwitchCore

struct NativeFuelWindow: View {
    @ObservedObject var model: AppModel
    let window: LimitWindow?
    var showsReset = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let window {
                HStack(spacing: 4) {
                    Text("\(Int(window.remainingPercent))%")
                        .monospacedDigit()
                    if window.isLowFuel {
                        Image(systemName: "fuelpump.fill").foregroundStyle(.orange)
                            .accessibilityLabel(model.t(.lowFuelWarning))
                    }
                }
                ProgressView(value: min(100, window.remainingPercent), total: 100)
                    .tint(window.isLowFuel ? .orange : .accentColor)
                    .accessibilityLabel(model.t(.remainingFuel))
                if showsReset, let reset = window.resetsAt {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        HStack(spacing: 3) {
                            Text(model.t(.resetsIn))
                            Text(reset, style: .relative)
                        }.font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("—").accessibilityLabel(model.t(.waitingTelemetry))
            }
        }.padding(.vertical, 4)
    }
}

struct NativeUsageStatus: View {
    @ObservedObject var model: AppModel
    let usage: AccountUsage?

    var body: some View {
        Group {
            if let usage {
                switch usage.staleness {
                case .fresh: EmptyView()
                case .cached(let since):
                    Text(String(format: model.t(.cachedTelemetry), ResetFormatter.stringSince(since)))
                        .foregroundStyle(.secondary)
                case .error(let message):
                    Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
            } else {
                Text(model.t(.awaitingCheck)).foregroundStyle(.secondary)
            }
        }
    }
}
