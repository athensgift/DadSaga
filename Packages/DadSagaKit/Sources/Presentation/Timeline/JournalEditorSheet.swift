import DesignSystem
import SwiftUI

/// Adds, changes or removes the note and photo on a timeline entry.
struct JournalEditorSheet: View {
    let editor: JournalEditor
    let isSaving: Bool
    let loader: PhotoLoader
    let onSave: (_ note: String, _ photo: MomentPhotoEdit) -> Void
    let onClose: () -> Void
    @State private var note: String
    @State private var photo: MomentPhotoEdit = .keep

    init(
        editor: JournalEditor,
        isSaving: Bool,
        loader: @escaping PhotoLoader,
        onSave: @escaping (_ note: String, _ photo: MomentPhotoEdit) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.editor = editor
        self.isSaving = isSaving
        self.loader = loader
        self.onSave = onSave
        self.onClose = onClose
        _note = State(initialValue: editor.note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.m) {
                    JournalNoteField(placeholder: editor.labels.notePlaceholder, note: $note)
                    JournalPhotoField(
                        photo: $photo, storedPhotoID: editor.photoIDs.first, labels: editor.labels.photo, loader: loader
                    )
                }
                .frame(maxWidth: readableWidth)
                .padding(DSSpacing.m)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DSColor.background)
            .navigationTitle(editor.title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { onSave(note, photo) }
                        .disabled(isSaving)
                        .accessibilityLabel(editor.saveTitle)
                }
            }
        }
    }
}
