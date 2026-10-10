import SwiftUI
import AppKit
import FuelSwitchCore

struct MenuCockpitHeader: View {
    @ObservedObject var model: AppModel
    let isSigningIn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            branding
            Spacer()
            headerActions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FuelSwitchTheme.bgPanel)
        .overlay(
            Rectangle()
                .fill(FuelSwitchTheme.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var branding: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(FuelSwitchTheme.amber.opacity(0.18)).frame(width: 28, height: 28)
                BrandIcon(size: 28).foregroundStyle(FuelSwitchTheme.amber)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(model.t(.appName)).font(.system(size: 13, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
                    Circle().fill(FuelSwitchTheme.emerald).frame(width: 5, height: 5)
                        .shadow(color: FuelSwitchTheme.emerald.opacity(0.7), radius: 3)
                }
                Text(model.t(.tagline)).font(.system(size: 9.5, weight: .medium)).foregroundStyle(FuelSwitchTheme.textTertiary)
            }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            hudMenu
            addTankMenu
            refreshButton
            settingsButton
            quitButton
        }
    }

    private var hudMenu: some View {
        Menu {
            Button(model.showFloatingWidget ? model.t(.hudOff) : model.t(.hudOn)) {
                model.showFloatingWidget.toggle()
            }
            Divider()
            Button("✓ " + model.t(.hudExpanded)) {
                model.widgetStyle = "expanded"
                if !model.showFloatingWidget { model.showFloatingWidget = true }
            }.disabled(model.widgetStyle == "expanded" && model.showFloatingWidget)
            Button(model.widgetStyle == "compact" ? "✓ " + model.t(.hudCompact) : model.t(.hudCompact)) {
                model.widgetStyle = "compact"
                if !model.showFloatingWidget { model.showFloatingWidget = true }
            }.disabled(model.widgetStyle == "compact" && model.showFloatingWidget)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.showFloatingWidget ? "macwindow.on.rectangle" : "macwindow").font(.system(size: 11))
                Text(model.showFloatingWidget ? (model.widgetStyle == "compact" ? model.t(.hudCompact) : model.t(.hudOn)) : model.t(.hudOff))
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 7).padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 6).fill(model.showFloatingWidget ? FuelSwitchTheme.amber.opacity(0.2) : Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(model.showFloatingWidget ? FuelSwitchTheme.amber.opacity(0.4) : Color.clear, lineWidth: 0.8))
            .foregroundStyle(model.showFloatingWidget ? FuelSwitchTheme.amber : FuelSwitchTheme.textSecondary)
        }
        .menuStyle(.borderlessButton).fixedSize().help(model.t(.toggleHudHelp))
    }

    private var addTankMenu: some View {
        Menu {
            Button(model.t(.connectClaude)) { model.startLogin(provider: .anthropic) }
            Button(model.t(.connectCodex)) { model.startLogin(provider: .openai) }
            Button(model.t(.connectGemini)) { model.startLogin(provider: .gemini) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                Text(model.t(.addTank)).font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 7).padding(.vertical, 3.5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
            .foregroundStyle(FuelSwitchTheme.textPrimary)
        }
        .menuStyle(.borderlessButton).fixedSize().disabled(isSigningIn)
    }

    private var refreshButton: some View {
        Button { model.refreshNow() } label: {
            Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FuelSwitchTheme.textSecondary)
                .rotationEffect(.degrees(model.isRefreshing ? 360 : 0))
                .animation(model.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: model.isRefreshing)
        }
        .buttonStyle(.plain).disabled(model.isRefreshing)
        .help(model.isRefreshing ? model.t(.telemetryInProgress) : model.t(.refresh))
    }

    private var settingsButton: some View {
        Button { model.showingSettings = true } label: {
            Image(systemName: "gearshape").font(.system(size: 11, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textSecondary)
        }
        .buttonStyle(.plain).help(model.t(.settings))
    }

    private var quitButton: some View {
        Button { NSApplication.shared.terminate(nil) } label: {
            Image(systemName: "power").font(.system(size: 11, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textTertiary)
        }
        .buttonStyle(.plain).help(model.t(.quit))
    }
}
