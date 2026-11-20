import DesignSystem
import SwiftUI

/// Adds, changes or removes the note and photos on a timeline entry. On an iPhone Duo half-open like a laptop, the
/// cover photo stands above the fold and the note and the other photos lie below it (ADR-0043). An entry with no
/// photo stays as it is: nothing asks for one.
struct JournalEditorSheet: View {
    let editor: JournalEditor
    let isSaving: Bool
    /// Why the last save failed, shown in the sheet.
    let errorMessage: String?
    let loader: PhotoLoader
    let onSave: (_ note: String, _ photos: PhotoDrafts) -> Void
    let onClose: () -> Void
    @State private var note: String
    @State private var photos: PhotoDrafts
    @State private var isConfirmingDiscard = false

    init(
        editor: JournalEditor,
        isSaving: Bool,
        errorMessage: String?,
        loader: @escaping PhotoLoader,
        onSave: @escaping (_ note: String, _ photos: PhotoDrafts) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.editor = editor
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.loader = loader
        self.onSave = onSave
        self.onClose = onClose
        _note = State(initialValue: editor.note)
        _photos = State(initialValue: PhotoDrafts(storedIDs: editor.photoIDs))
    }

    /// The note or the photos changed and not saved yet, or photos still arriving from the library.
    private var hasUnsavedChanges: Bool {
        note != editor.note || photos != PhotoDrafts(storedIDs: editor.photoIDs)
    }

    var body: some View {
        NavigationStack {
            CoverAndFormPanes(photos: photos, entry: editor.title, labels: editor.labels.photo, loader: loader) { showsCover in
                VStack(spacing: DSSpacing.m) {
                    JournalNoteField(
                        placeholder: editor.labels.notePlaceholder,
                        hideKeyboardTitle: editor.labels.hideKeyboard,
                        note: $note
                    )
                    JournalPhotosField(
                        photos: $photos,
                        entry: editor.title,
                        labels: editor.labels.photo,
                        loader: loader,
                        showsCover: showsCover
                    )
                    SheetError(message: errorMessage)
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .background(DSColor.background)
            .navigationTitle(editor.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        if hasUnsavedChanges { isConfirmingDiscard = true } else { onClose() }
                    }
                    // A save under way can't be discarded: it writes everything anyway.
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Saving several photos takes a moment: the button waits, and says so.
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(role: .confirm) { onSave(note, photos) }
                            .disabled(photos.isLoading)
                            .accessibilityLabel(editor.saveTitle)
                    }
                }
            }
            .modifier(UnsavedChangesGuard(
                hasUnsavedChanges: hasUnsavedChanges,
                isAsking: $isConfirmingDiscard,
                labels: editor.labels,
                canSave: !isSaving && !photos.isLoading,
                onSave: { onSave(note, photos) },
                onDiscard: onClose
            ))
        }
    }
}
