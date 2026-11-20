import Foundation
import Localization

/// Texts for showing an entry's photos full screen, and for the controls that open them (ADR-0042 §4).
public struct PhotoViewerLabels: Equatable, Sendable {
    public let close: String
    /// The action on a card or row that has photos.
    public let showPhotos: String
    private let locale: Locale

    init(locale: Locale) {
        let strings = Strings(locale: locale)
        close = strings.text("Close")
        showPhotos = strings.text("Show photos")
        self.locale = locale
    }

    /// e.g. "Φωτογραφία 2 από 5, 👣 Βήματα": what VoiceOver says for one photo of an entry.
    func photoLabel(number: Int, of count: Int, entry: String) -> String {
        Strings(locale: locale).text("Photo \(number) of \(count)") + ", " + entry
    }

    /// How many photos a card or row has, e.g. "3 φωτογραφίες"; `nil` without photos.
    func photoCount(_ photos: Int) -> String? {
        photos > 0 ? Strings(locale: locale).text("\(photos) photos") : nil
    }

    /// An entry's photos, opened at the one tapped.
    func content(entry: String, photos: [PhotoSource], startingAt index: Int = 0) -> PhotoViewerContent {
        PhotoViewerContent(
            title: entry,
            pages: photos.enumerated().map { offset, source in
                PhotoViewerContent.Page(
                    id: offset,
                    source: source,
                    label: photoLabel(number: offset + 1, of: photos.count, entry: entry)
                )
            },
            startIndex: min(max(index, 0), max(photos.count - 1, 0)),
            closeTitle: close
        )
    }
}

/// What the full-screen viewer shows: one entry's photos, in order. It has no view model: it shows what it is given
/// and keeps only its page and zoom.
struct PhotoViewerContent: Identifiable {
    struct Page: Identifiable {
        /// The page's place, from 0.
        let id: Int
        let source: PhotoSource
        /// e.g. "Photo 2 of 5, 👣 First steps".
        let label: String
    }

    /// New every time it opens, so tapping another photo opens afresh.
    let id = UUID()
    /// The entry, e.g. "👣 First steps".
    let title: String
    let pages: [Page]
    let startIndex: Int
    let closeTitle: String

    /// "2 / 5" at the top, or `nil` for a single photo.
    func counter(at index: Int) -> String? {
        pages.count > 1 ? "\(index + 1) / \(pages.count)" : nil
    }
}
