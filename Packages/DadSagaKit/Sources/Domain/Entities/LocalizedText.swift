import Foundation

/// Bilingual text used by bundled content. Greek is the primary language.
public struct LocalizedText: Hashable, Sendable {
    public let el: String
    public let en: String

    public init(el: String, en: String) {
        self.el = el
        self.en = en
    }

    /// Greek for Greek locales, English for everything else.
    public func resolved(for locale: Locale = .current) -> String {
        locale.language.languageCode?.identifier == "el" ? el : en
    }
}
