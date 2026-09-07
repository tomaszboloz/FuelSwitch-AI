import Testing
import Foundation
@testable import FuelSwitchCore

@Test func allTwelveLanguagesAreSupported() {
    let supported = AppLanguage.allCases
    #expect(supported.count == 12)
    
    let codes = Set(supported.map(\.rawValue))
    let expectedCodes: Set<String> = ["en", "pl", "es", "de", "fr", "ja", "zh", "pt", "ru", "ko", "hi", "ar"]
    #expect(codes == expectedCodes)
}

@Test func arabicIsIdentifiedAsRTL() {
    #expect(AppLanguage.arabic.isRTL == true)
    #expect(AppLanguage.english.isRTL == false)
    #expect(AppLanguage.polish.isRTL == false)
    #expect(AppLanguage.japanese.isRTL == false)
}

@Test func languageDisplaysNativeNames() {
    #expect(AppLanguage.polish.nativeName == "Polski")
    #expect(AppLanguage.english.nativeName == "English")
    #expect(AppLanguage.arabic.nativeName == "العربية")
    #expect(AppLanguage.japanese.nativeName == "日本語")
    #expect(AppLanguage.german.nativeName == "Deutsch")
}

@Test func everyTranslationKeyExistsInEverySupportedLanguage() {
    for lang in AppLanguage.allCases {
        #expect(
            Translations.missingKeys(in: lang).isEmpty,
            "Missing translations for \(lang): \(Translations.missingKeys(in: lang))"
        )
    }
}

@Test func localizationManagerChangesLanguage() {
    let name = UUID().uuidString
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }

    let manager = LocalizationManager(defaults: defaults)
    manager.setLanguage(.polish)
    #expect(manager.currentLanguage == .polish)
    #expect(manager.text(.allTanks) == "Wszystkie")

    // Check persistence
    let reloaded = LocalizationManager(defaults: defaults)
    #expect(reloaded.currentLanguage == .polish)
}
