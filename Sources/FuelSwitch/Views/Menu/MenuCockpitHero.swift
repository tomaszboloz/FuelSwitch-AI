import SwiftUI
import FuelSwitchCore

struct MenuCockpitHero: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            heroCard(for: .anthropic, activeEmail: model.activeClaudeEmail)
            heroCard(for: .openai, activeEmail: model.activeCodexEmail)
            heroCard(for: .gemini, activeEmail: model.activeGeminiEmail)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func heroCard(for provider: Provider, activeEmail: String?) -> some View {
        let matchingAccount = model.accounts.first { $0.provider == provider && $0.email.lowercased() == activeEmail?.lowercased() }
        let usage = matchingAccount.flatMap { model.usage[$0.id] }

        let (iconColor, iconName): (Color, String) = {
            switch provider {
            case .anthropic: return (Color(red: 0.95, green: 0.60, blue: 0.40), "sparkles")
            case .openai: return (Color(red: 0.30, green: 0.85, blue: 0.70), "terminal.fill")
            case .gemini: return (Color(red: 0.35, green: 0.65, blue: 0.98), "diamond.fill")
            }
        }()

        return HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(iconColor.opacity(0.18)).frame(width: 26, height: 26)
                Image(systemName: iconName).font(.system(size: 11, weight: .bold)).foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(provider.displayName).font(.system(size: 10, weight: .bold)).foregroundStyle(FuelSwitchTheme.textPrimary)
                    if matchingAccount != nil {
                        Text(model.t(.active)).font(.system(size: 7, weight: .heavy)).foregroundStyle(FuelSwitchTheme.emerald)
                            .padding(.horizontal, 3).background(FuelSwitchTheme.emerald.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                if let email = activeEmail {
                    Text(email).font(.system(size: 9)).foregroundStyle(FuelSwitchTheme.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text(model.t(.noActiveCliAccount)).font(.system(size: 9)).foregroundStyle(FuelSwitchTheme.textTertiary)
                }
            }

            Spacer()

            if let usage {
                HStack(spacing: 5) {
                    if usage.isLowFuel {
                        Image(systemName: "fuelpump.fill").font(.system(size: 9.5, weight: .bold)).foregroundStyle(FuelSwitchTheme.amber)
                    }
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(usage.remainingPercent))%").font(.system(size: 11, weight: .heavy).monospacedDigit())
                            .foregroundStyle(FuelSwitchTheme.fuelColor(percentUsed: usage.worstPercent))
                        Text(model.t(.remainingFuel)).font(.system(size: 7.5, weight: .semibold)).foregroundStyle(FuelSwitchTheme.textTertiary)
                    }
                }
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(FuelSwitchTheme.bgCardSubtle))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(matchingAccount != nil ? FuelSwitchTheme.borderRegular : FuelSwitchTheme.borderSubtle, lineWidth: 1))
    }
}
