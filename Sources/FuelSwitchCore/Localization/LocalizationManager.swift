import Foundation
import SwiftUI
import Combine

/// All 12 supported locales in FuelSwitch AI
public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case english = "en"
    case polish = "pl"
    case spanish = "es"
    case hindi = "hi"
    case chinese = "zh"
    case japanese = "ja"
    case german = "de"
    case french = "fr"
    case portuguese = "pt"
    case arabic = "ar"
    case russian = "ru"
    case korean = "ko"

    public var id: String { rawValue }

    /// Native name displayed in language picker
    public var nativeName: String {
        switch self {
        case .english: "English"
        case .polish: "Polski"
        case .spanish: "Español"
        case .hindi: "हिन्दी"
        case .chinese: "中文"
        case .japanese: "日本語"
        case .german: "Deutsch"
        case .french: "Français"
        case .portuguese: "Português"
        case .arabic: "العربية"
        case .russian: "Русский"
        case .korean: "한국어"
        }
    }

    /// Whether this language reads Right-to-Left
    public var isRTL: Bool {
        self == .arabic
    }

    public var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }
}

public final class LocalizationManager: ObservableObject, @unchecked Sendable {
    public static let shared = LocalizationManager()
    private static let languageKey = "FuelSwitch_App_Language"

    private let defaults: UserDefaults
    @Published public var currentLanguage: AppLanguage {
        didSet {
            defaults.set(currentLanguage.rawValue, forKey: Self.languageKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: Self.languageKey),
           let lang = AppLanguage(rawValue: stored) {
            self.currentLanguage = lang
        } else {
            // Check system preferred language
            let preferred = Locale.preferredLanguages.first?.prefix(2) ?? "en"
            self.currentLanguage = AppLanguage(rawValue: String(preferred)) ?? .english
        }
    }

    public func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
    }

    public func text(_ key: TranslationKey) -> String {
        Translations.lookup(key, in: currentLanguage)
    }
}
