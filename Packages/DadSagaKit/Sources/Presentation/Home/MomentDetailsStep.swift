import DesignSystem
import SwiftUI

/// Step 2: the moment's own page, for photos, a few words and the date (ADR-0042 §5). Just recorded, it offers
/// "Saved · Undo" here, since home is behind the sheet, and home celebrates once it closes; opened to edit, it offers
/// Delete instead.
/// On an iPhone Duo half-open like a laptop its heading, and its cover once it has one, stand above the fold, and
/// what the dad fills in lies below it (ADR-0043).
/// Closing never loses the moment: only what was changed and not saved, and only after asking.
struct MomentDetailsStep: View {
    let details: MomentDetails
    let errorMessage: String?
    let isSaving: Bool
    let loader: PhotoLoader
    let actions: MomentSheet.Actions

    @State private var date: Date
    @State private var note: String
    @State private var photos: PhotoDrafts
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingDelete = false
    /// The cover full screen, opened from above the fold.
    @State private var coverViewer: PhotoViewerContent?

    /// The cover's height above the fold, where it shares the pane with the heading.
    private static let coverHeight: CGFloat = 200

    init(
        details: MomentDetails,
        errorMessage: String?,
        isSaving: Bool,
        loader: @escaping PhotoLoader,
        actions: MomentSheet.Actions
    ) {
        self.details = details
        self.errorMessage = errorMessage
        self.isSaving = isSaving
        self.loader = loader
        self.actions = actions
        _date = State(initialValue: details.date)
        _note = State(initialValue: details.note)
        _photos = State(initialValue: PhotoDrafts(storedIDs: details.photoIDs))
    }

    /// Photos, words or the date changed and not saved yet, or photos still arriving from the library.
    private var hasUnsavedChanges: Bool {
        photos != PhotoDrafts(storedIDs: details.photoIDs) || note != details.note || date != details.date
    }

    var body: some View {
        // Split, the moment's heading and its cover stand above the fold; everything to fill in lies below it.
        ReadAndActPanes(alignment: .leading, flatTitle: .inline, column: MomentColumn()) { isSplit in
            header
            if isSplit, let cover = photos.items.first {
                JournalCover(source: cover.source, loader: loader) {
                    coverViewer = details.labels.journal.photo.viewer.content(
                        entry: details.title, photos: photos.items.map(\.source), startingAt: 0
                    )
                }
                .frame(height: Self.coverHeight)
            }
        } acting: { isSplit in
            JournalPhotosField(
                photos: $photos,
                entry: details.title,
                labels: details.labels.journal.photo,
                loader: loader,
                showsCover: !isSplit
            )
            JournalNoteField(
                placeholder: details.notePlaceholder,
                hideKeyboardTitle: details.labels.journal.hideKeyboard,
                note: $note
            )
            DateRow(label: details.dateLabel, date: $date, range: details.earliestDate...details.latestDate)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .padding(.horizontal, DSSpacing.m)
                .frame(minHeight: 50)
                .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            SheetError(message: errorMessage)
            buttons
        }
        .photoViewer($coverViewer, loader: loader)
        .background(DSColor.background)
        .safeAreaInset(edge: .bottom) { undoBar }
        .motion(.spring(response: 0.35, dampingFraction: 0.8), value: details.undoOffer)
        .navigationTitle(details.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    if hasUnsavedChanges { isConfirmingDiscard = true } else { actions.onClose() }
                }
                // A save under way can't be discarded: it writes everything anyway.
                .disabled(isSaving)
            }
        }
        .modifier(UnsavedChangesGuard(
            hasUnsavedChanges: hasUnsavedChanges,
            isAsking: $isConfirmingDiscard,
            labels: details.labels.journal,
            canSave: !isSaving && !photos.isLoading,
            onSave: { actions.onSave(date, note, photos) },
            onDiscard: actions.onClose
        ))
        .confirmationDialog(details.labels.deleteConfirmation, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(details.labels.delete, role: .destructive, action: actions.onDelete)
            Button(details.labels.cancel, role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let heading = details.heading {
                Text(heading)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            if let line = details.line {
                Text(line)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var buttons: some View {
        VStack(spacing: DSSpacing.s) {
            // Saving several photos takes a moment: the button waits, and says so.
            PrimaryButton(details.saveTitle) { actions.onSave(date, note, photos) }
                .disabled(isSaving || photos.isLoading)
                .overlay(alignment: .trailing) {
                    if isSaving { ProgressView().padding(.trailing, DSSpacing.m) }
                }
            if !details.isNew {
                Button(details.labels.delete, systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    .padding(.top, DSSpacing.s)
            } else if !hasUnsavedChanges {
                Button(details.notNowTitle, action: actions.onClose)
                    .font(DSFont.headline)
                    .padding(.vertical, DSSpacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSSpacing.s)
    }

    @ViewBuilder private var undoBar: some View {
        if let offer = details.undoOffer {
            UndoBar(offer: offer, onUndo: actions.onDelete) {
                actions.onUndoExpired(offer.id)
            }
            // While Save runs, an Undo would be refused: it waits instead of being lost.
            .disabled(isSaving)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The details page's column.
private struct MomentColumn: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
    }
}
