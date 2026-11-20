import Domain
import Foundation
import Localization

/// Texts for picking and arranging an entry's photos (ADR-0042 §3).
public struct PhotoLabels: Equatable, Sendable {
    public let addPhotos: String
    public let takePhoto: String
    /// Marks the first photo, which shows on every thumbnail.
    public let cover: String
    public let makeCover: String
    public let remove: String
    /// The one plain line once an entry holds ten.
    public let limitReached: String
    public let viewer: PhotoViewerLabels

    init(locale: Locale) {
        let strings = Strings(locale: locale)
        addPhotos = strings.text("Add photos")
        takePhoto = strings.text("Take a photo")
        cover = strings.text("Cover")
        makeCover = strings.text("Make cover")
        remove = strings.text("Remove")
        limitReached = strings.text("Up to \(ProgressEvent.photoLimit) photos on each entry.")
        viewer = PhotoViewerLabels(locale: locale)
    }
}

/// Texts for the dad's own note and photos on an entry.
public struct JournalLabels: Equatable, Sendable {
    /// The optional section's heading, e.g. "Σημείωση ή φωτογραφίες (προαιρετικά)".
    public let sectionTitle: String
    public let notePlaceholder: String
    public let photo: PhotoLabels

    init(locale: Locale) {
        let strings = Strings(locale: locale)
        sectionTitle = strings.text("Note or photos (optional)")
        notePlaceholder = strings.text("What happened? What do you want to remember?")
        photo = PhotoLabels(locale: locale)
    }
}

/// What the dad left on this card last time, shown when he opens it again.
public struct LastJournal: Equatable, Sendable {
    /// e.g. "Την προηγούμενη φορά (3 Νοε) έγραψες:".
    public let title: String
    public let note: String?
    /// In his order; the first is the cover.
    public let photoIDs: [String]
}
