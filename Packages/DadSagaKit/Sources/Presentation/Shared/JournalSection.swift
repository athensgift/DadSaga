import DesignSystem
import SwiftUI

/// The optional note and photos on a card's sheet. Folded away until the dad asks for it, so it never feels like a
/// form he has to fill in.
struct JournalSection: View {
    let labels: JournalLabels
    @Binding var note: String
    @Binding var photos: PhotoDrafts
    /// The card's title, for VoiceOver in the photo viewer.
    let entry: String
    let loader: PhotoLoader
    /// The note field's background: it must differ from the sheet's.
    let fill: Color
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            if isOpen {
                JournalNoteField(
                    placeholder: labels.notePlaceholder, hideKeyboardTitle: labels.hideKeyboard, note: $note, fill: fill
                )
                JournalPhotosField(photos: $photos, entry: entry, labels: labels.photo, loader: loader)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isOpen = true }
                } label: {
                    Label(labels.sectionTitle, systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

/// A few lines of the dad's own words. While he writes, a button over the keyboard puts it away: Return starts a
/// new line here, and a swipe down is hard to find.
struct JournalNoteField: View {
    let placeholder: String
    /// What the button over the keyboard is called, for VoiceOver.
    let hideKeyboardTitle: String
    @Binding var note: String
    var fill: Color = DSColor.surface
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $note, axis: .vertical)
            .focused($isFocused)
            .lineLimit(2...6)
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .padding(DSSpacing.m)
            .background(fill, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .toolbar {
                // Only from the field being written in: another field on the screen adds no second button.
                if isFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(hideKeyboardTitle, systemImage: "keyboard.chevron.compact.down") { isFocused = false }
                            .labelStyle(.iconOnly)
                    }
                }
            }
    }
}

/// "Last time you wrote: …", with the photos if there were any: a tap on the thumbnail shows them full screen.
struct LastJournalView: View {
    let last: LastJournal
    /// The card's title, for VoiceOver in the photo viewer.
    let entry: String
    let viewerLabels: PhotoViewerLabels
    let loader: PhotoLoader
    /// The photos full screen. The sheet presents them, so they stay up when this view moves between layouts.
    @Binding var viewer: PhotoViewerContent?

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            if !last.photoIDs.isEmpty {
                Button(action: showPhotos) {
                    PhotoThumbnail(photoIDs: last.photoIDs, loader: loader, size: 56, placeholder: DSColor.surface)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(last.title)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                if let note = last.note {
                    Text(note)
                        .font(DSFont.body)
                        .italic()
                        .foregroundStyle(DSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.leading)
        .padding(DSSpacing.m)
        .background(DSColor.legendary.opacity(0.1), in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(viewerLabels.photoCount(last.photoIDs.count) ?? "")
        .accessibilityActions {
            if !last.photoIDs.isEmpty {
                Button(viewerLabels.showPhotos, action: showPhotos)
            }
        }
    }

    private func showPhotos() {
        viewer = viewerLabels.content(entry: entry, photos: last.photoIDs.map(PhotoSource.stored))
    }
}
