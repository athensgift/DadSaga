import Domain
import Foundation

/// UI text from the shared String Catalog, in Greek or English (ADR-0027). Presenters hold one, built from their locale.
public struct Strings: Sendable {
    /// The full locale, for formatting dates and numbers.
    public let locale: Locale
    /// "el" or "en", by the same rule as content.
    private let lookup: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
        lookup = Locale(identifier: LocalizedText.languageCode(for: locale))
    }

    /// The catalog entry for `key`: its English text, with `\(…)` values filled in.
    public func text(_ key: String.LocalizationValue) -> String {
        var resource = LocalizedStringResource(key, table: nil, locale: lookup, bundle: .atURL(Bundle.module.bundleURL))
        resource.locale = lookup
        #if DEBUG
        let sentinel = "\u{1}missing"
        assert(
            Bundle.module.localizedString(forKey: resource.key, value: sentinel, table: nil) != sentinel,
            "Missing from Localizable.xcstrings: \(resource.key)"
        )
        #endif
        return String(localized: resource)
    }

    /// The skill's name, e.g. "Φροντίδα" or "Care".
    public func skill(_ skill: Skill) -> String {
        switch skill {
        case .care: text("Care")
        case .play: text("Play")
        case .patience: text("Patience")
        case .resilience: text("Resilience")
        }
    }

    /// What doing a card grew, e.g. "Η υπομονή σου μεγάλωσε" or "Your patience grew". Never a number (ADR-0055 §6).
    public func skillGrew(_ skill: Skill) -> String {
        switch skill {
        case .care: text("Your care grew")
        case .play: text("Your play grew")
        case .patience: text("Your patience grew")
        case .resilience: text("Your resilience grew")
        }
    }

    /// A short day, e.g. "18 Νοε" or "Nov 18", in the full locale.
    public func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale).day().month(.abbreviated))
    }
}
