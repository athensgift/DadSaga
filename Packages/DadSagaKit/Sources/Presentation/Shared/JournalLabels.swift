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
    /// The one plain line once an entry holds as many as it can (`ProgressEvent.photoLimit`).
    public let limitReached: String
    public let viewer: PhotoViewerLabels
    private let locale: Locale

    init(locale: Locale) {
        self.locale = locale
        let strings = Strings(locale: locale)
        addPhotos = strings.text("Add photos")
        takePhoto = strings.text("Take a photo")
        cover = strings.text("Cover")
        makeCover = strings.text("Make cover")
        remove = strings.text("Remove")
        limitReached = strings.text("Up to \(ProgressEvent.photoLimit) photos on each entry.")
        viewer = PhotoViewerLabels(locale: locale)
    }

    /// "2 photos couldn't be opened. If they're in iCloud, try again in a moment."
    public func couldNotOpen(_ count: Int) -> String {
        Strings(locale: locale).text("\(count) photos couldn't be opened. If they're in iCloud, try again in a moment.")
    }
}

/// Texts for the dad's own note and photos on an entry.
public struct JournalLabels: Equatable, Sendable {
    /// The optional section's heading, e.g. "Σημείωση ή φωτογραφίες (προαιρετικά)".
    public let sectionTitle: String
    public let notePlaceholder: String
    public let photo: PhotoLabels
    /// Closing with changes not saved: "Discard the changes you just made?", and its answers.
    public let discardQuestion: String
    public let save: String
    public let discard: String
    public let keepEditing: String
    /// The button just above the keyboard that puts it away.
    public let hideKeyboard: String

    init(locale: Locale) {
        let strings = Strings(locale: locale)
        sectionTitle = strings.text("Note or photos (optional)")
        notePlaceholder = strings.text("What happened? What do you want to remember?")
        photo = PhotoLabels(locale: locale)
        discardQuestion = strings.text("Discard the changes you just made?")
        save = strings.text("Save")
        discard = strings.text("Discard")
        keepEditing = strings.text("Keep editing")
        hideKeyboard = strings.text("Hide keyboard")
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
