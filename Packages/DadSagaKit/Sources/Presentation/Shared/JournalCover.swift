import DesignSystem
import SwiftUI

/// An entry's cover photo, whole; a tap opens it full screen. Drawn at the top of the photos field, or above the
/// fold of a half-open iPhone Duo (ADR-0043).
struct JournalCover: View {
    let source: PhotoSource
    let loader: PhotoLoader
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            WholePhoto(source: source, loader: loader)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        // The cover's square says the same and carries the actions: VoiceOver reads the cover once.
        .accessibilityHidden(true)
    }
}

extension PhotoDrafts {
    /// The photo that has the upper pane of a sheet split at a fold: the cover. An entry with no photo has none, so
    /// the upper half never shows an empty frame waiting for one (ADR-0006, ADR-0042); nor has a flat sheet.
    func cover(for panes: FoldedPanes) -> PhotoDraft? {
        panes == .flat ? nil : items.first
    }
}

/// A sheet's form for an entry with photos. On an iPhone Duo half-open like a laptop, the cover stands above the
/// fold and the form lies below it (ADR-0043); everywhere else, and for an entry with no photo, it is the form alone.
///
/// The form keeps its place in the view tree in every layout, so a fold keeps the note's focus, an open picker and
/// photos still loading. With the keyboard up there is no room below the fold: the form alone shows above the
/// keyboard, where it was, and the cover comes back when the keyboard goes.
struct CoverAndFormPanes<Form: View>: View {
    let photos: PhotoDrafts
    /// The entry, for VoiceOver in the viewer.
    let entry: String
    let labels: PhotoLabels
    let loader: PhotoLoader
    /// The form's column; `showsCover` is `false` while the cover has the upper pane.
    @ViewBuilder let form: (_ showsCover: Bool) -> Form

    @State private var foldedPanes = FoldedPanes.flat
    /// The cover full screen, opened from above the fold.
    @State private var viewer: PhotoViewerContent?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let cover = photos.cover(for: foldedPanes)
        let panes = cover == nil ? FoldedPanes.flat : foldedPanes
        panes.layout {
            if let cover {
                JournalCover(source: cover.source, loader: loader) {
                    viewer = labels.viewer.content(entry: entry, photos: photos.items.map(\.source), startingAt: 0)
                }
                .padding(DSSpacing.m)
                .hiddenUpperPane(panes)
            }
            ScrollView { form(cover == nil) }
                .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(FoldedPanesReader(panes: $foldedPanes))
        .modifier(HideKeyboardBar())
        .animation(reduceMotion ? nil : .smooth, value: panes)
        .photoViewer($viewer, loader: loader)
    }
}
