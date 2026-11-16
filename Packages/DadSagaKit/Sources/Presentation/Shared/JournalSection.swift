import DesignSystem
import SwiftUI

/// The optional note and photo on a card's sheet. Folded away until the dad asks for it, so it never feels like a
/// form he has to fill in.
struct JournalSection: View {
    let labels: JournalLabels
    @Binding var note: String
    @Binding var photo: MomentPhotoEdit
    let loader: PhotoLoader
    /// The note field's background: it must differ from the sheet's.
    let fill: Color
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            if isOpen {
                JournalNoteField(placeholder: labels.notePlaceholder, note: $note, fill: fill)
                JournalPhotoField(photo: $photo, storedPhotoID: nil, labels: labels.photo, loader: loader)
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

/// A few lines of the dad's own words.
struct JournalNoteField: View {
    let placeholder: String
    @Binding var note: String
    var fill: Color = DSColor.surface

    var body: some View {
        TextField(placeholder, text: $note, axis: .vertical)
            .lineLimit(2...6)
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .padding(DSSpacing.m)
            .background(fill, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}

/// "Last time you wrote: …", with the photo if there was one.
struct LastJournalView: View {
    let last: LastJournal
    let loader: PhotoLoader

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            if last.photoID != nil {
                MomentPhoto(photoID: last.photoID, loader: loader) { DSColor.surface }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.tile, style: .continuous))
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
    }
}
