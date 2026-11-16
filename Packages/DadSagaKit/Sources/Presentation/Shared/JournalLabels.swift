import Domain
import Foundation

extension PhotoLabels {
    init(locale: Locale) {
        func text(_ el: String, _ en: String) -> String { LocalizedText(el: el, en: en).resolved(for: locale) }
        self.init(
            addPhoto: text("Πρόσθεσε φωτογραφία", "Add a photo"),
            takePhoto: text("Τράβηξε φωτογραφία", "Take a photo"),
            changePhoto: text("Άλλη φωτογραφία", "Choose another"),
            removePhoto: text("Αφαίρεση φωτογραφίας", "Remove photo")
        )
    }
}

/// Texts for the dad's own note and photo on an entry.
public struct JournalLabels: Equatable, Sendable {
    /// The optional section's heading, e.g. "Σημείωση ή φωτογραφία (προαιρετικά)".
    public let sectionTitle: String
    public let notePlaceholder: String
    public let photo: PhotoLabels

    init(locale: Locale) {
        func text(_ el: String, _ en: String) -> String { LocalizedText(el: el, en: en).resolved(for: locale) }
        sectionTitle = text("Σημείωση ή φωτογραφία (προαιρετικά)", "Note or photo (optional)")
        notePlaceholder = text("Τι έγινε; Τι θες να θυμάσαι;", "What happened? What do you want to remember?")
        photo = PhotoLabels(locale: locale)
    }
}

/// What the dad left on this card last time, shown when he opens it again.
public struct LastJournal: Equatable, Sendable {
    /// e.g. "Την προηγούμενη φορά (3 Νοε) έγραψες:".
    public let title: String
    public let note: String?
    public let photoID: String?
}
