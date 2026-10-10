import SwiftUI
import FuelSwitchCore

struct MenuEmptyState: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(FuelSwitchTheme.amber.opacity(0.1)).frame(width: 48, height: 48)
                Image(systemName: "fuelpump.fill").font(.system(size: 22)).foregroundStyle(FuelSwitchTheme.amber)
            }

            VStack(spacing: 4) {
                Text(model.t(.noAccountsRegistered)).font(.system(size: 13, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
                Text(model.t(.connectMonitor)).font(.system(size: 11)).foregroundStyle(FuelSwitchTheme.textTertiary).multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Button { model.startLogin(provider: .anthropic) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text(model.t(.addClaude))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.amber.opacity(0.18)))
                    .foregroundStyle(FuelSwitchTheme.amber)
                }
                .buttonStyle(.plain)

                Button { model.startLogin(provider: .openai) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "terminal.fill")
                        Text(model.t(.addCodex))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button { model.startLogin(provider: .gemini) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "diamond.fill")
                        Text(model.t(.addGemini))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    .foregroundStyle(FuelSwitchTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}
