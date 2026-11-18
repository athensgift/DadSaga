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
        Self.languageCode(for: locale) == "el" ? el : en
    }

    /// "el" for Greek locales, "en" for everything else. UI text follows the same rule (ADR-0027), so the screen and
    /// the content are never in two languages.
    public static func languageCode(for locale: Locale) -> String {
        locale.language.languageCode?.identifier == "el" ? "el" : "en"
    }
}
