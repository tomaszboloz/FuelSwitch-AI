/// Layout choice, independent of light/dark appearance and widget size.
public enum InterfaceTemplate: String, CaseIterable, Sendable, Identifiable {
    case classic
    case native

    public var id: String { rawValue }
    public var titleKey: TranslationKey {
        switch self {
        case .classic: .templateClassic
        case .native: .templateNative
        }
    }
}
