import DesignSystem
import SwiftUI

/// Step 2: the moment's own page, for photos, a few words and the date (ADR-0042 §5). Just recorded, it celebrates
/// and offers "Saved · Undo" here, since home is behind the sheet; opened to edit, it offers Delete instead.
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
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.m) {
                header
                JournalPhotosField(photos: $photos, entry: details.title, labels: details.labels.journal.photo, loader: loader)
                JournalNoteField(placeholder: details.notePlaceholder, note: $note)
                DateRow(label: details.dateLabel, date: $date, range: details.earliestDate...details.latestDate)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(.horizontal, DSSpacing.m)
                    .frame(minHeight: 50)
                    .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                SheetError(message: errorMessage)
                buttons
            }
            .frame(maxWidth: readableWidth)
            .padding(DSSpacing.m)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DSColor.background)
        .modifier(CelebrationOverlay(celebration: details.celebration, onFinished: actions.onCelebrationFinished))
        .safeAreaInset(edge: .bottom) { undoBar }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: details.undoOffer)
        .navigationTitle(details.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    if hasUnsavedChanges { isConfirmingDiscard = true } else { actions.onClose() }
                }
            }
        }
        // A swipe would lose what was just added; Close asks first instead.
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog(details.labels.discardQuestion, isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button(details.labels.discard, role: .destructive, action: actions.onClose)
            Button(details.labels.keepEditing, role: .cancel) {}
        }
        .confirmationDialog(details.labels.deleteConfirmation, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(details.labels.delete, role: .destructive, action: actions.onDelete)
            Button(details.labels.cancel, role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(details.reward)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.legendary)
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
            // Saving ten photos takes a second or two: the button waits, and says so.
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
