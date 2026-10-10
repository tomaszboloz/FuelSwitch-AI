import Foundation

public struct Translations {
    public static func lookup(_ key: TranslationKey, in language: AppLanguage) -> String {
        table[language]?[key] ?? table[.english]?[key] ?? key.rawValue
    }

    /// Used by the test suite to make a missing entry a release-blocking error
    /// instead of quietly falling back to English.
    static func missingKeys(in language: AppLanguage) -> [TranslationKey] {
        TranslationKey.allCases.filter { table[language]?[$0]?.isEmpty ?? true }
    }

    private static let table: [AppLanguage: [TranslationKey: String]] = [
        .english: englishTable,
        .polish: polishTable,
        .spanish: spanishTable,
        .german: germanTable,
        .french: frenchTable,
        .japanese: japaneseTable,
        .chinese: chineseTable,
        .portuguese: portugueseTable,
        .russian: russianTable,
        .korean: koreanTable,
        .hindi: hindiTable,
        .arabic: arabicTable,
    ]
}
