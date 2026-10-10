import SwiftUI
import ServiceManagement
import FuelSwitchCore

extension AppModel {
    var colorScheme: ColorScheme? {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    var localization: LocalizationManager { LocalizationManager.shared }
    func t(_ key: TranslationKey) -> String { localization.text(key) }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func activeEmail(for provider: Provider) -> String? {
        switch provider {
        case .anthropic: return activeClaudeEmail
        case .openai: return activeCodexEmail
        case .gemini: return activeGeminiEmail
        }
    }
}
