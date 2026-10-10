import SwiftUI

struct FloatingWidgetHeader: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(FuelSwitchTheme.amber.opacity(0.18)).frame(width: 22, height: 22)
                BrandIcon(size: 28).foregroundStyle(FuelSwitchTheme.amber)
                    .overlay(WidgetDragHandle().accessibilityHidden(true))
            }

            Text(model.t(.hudTitle)).font(.system(size: 12, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
            Spacer()
            actions
        }
        .padding(.bottom, 8)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Menu {
                Button(model.t(.connectClaude)) { model.startLogin(provider: .anthropic) }
                Button(model.t(.connectCodex)) { model.startLogin(provider: .openai) }
                Button(model.t(.connectGemini)) { model.startLogin(provider: .gemini) }
            } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 11)).foregroundStyle(FuelSwitchTheme.amber)
            }
            .menuStyle(.borderlessButton).help(model.t(.addAccount))

            Button { model.refreshNow() } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textSecondary)
                    .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                    .animation(model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isRefreshing)
            }
            .buttonStyle(.plain).help(model.t(.refresh))

            Button { model.widgetStyle = "compact" } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain).help(model.t(.hudCompact))

            Button { model.openSettings() } label: {
                Image(systemName: "gearshape").font(.system(size: 10, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textSecondary)
            }
            .buttonStyle(.plain).help(model.t(.settings))

            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.textTertiary).padding(4)
            }
            .buttonStyle(.plain)
        }
    }
}
