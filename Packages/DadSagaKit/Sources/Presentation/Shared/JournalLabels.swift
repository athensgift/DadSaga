import Domain
import Foundation
import Localization

extension PhotoLabels {
    init(locale: Locale) {
        let strings = Strings(locale: locale)
        self.init(
            addPhoto: strings.text("Add a photo"),
            takePhoto: strings.text("Take a photo"),
            changePhoto: strings.text("Choose another"),
            removePhoto: strings.text("Remove photo")
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
        let strings = Strings(locale: locale)
        sectionTitle = strings.text("Note or photo (optional)")
        notePlaceholder = strings.text("What happened? What do you want to remember?")
        photo = PhotoLabels(locale: locale)
    }
}

/// What the dad left on this card last time, shown when he opens it again.
public struct LastJournal: Equatable, Sendable {
    /// e.g. "Την προηγούμενη φορά (3 Νοε) έγραψες:".
    public let title: String
    public let note: String?
    /// The cover, if it had photos.
    public let photoID: String?
}
