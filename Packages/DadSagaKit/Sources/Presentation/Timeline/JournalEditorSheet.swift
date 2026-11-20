import DesignSystem
import SwiftUI

/// Adds, changes or removes the note and photos on a timeline entry.
struct JournalEditorSheet: View {
    let editor: JournalEditor
    let isSaving: Bool
    let loader: PhotoLoader
    let onSave: (_ note: String, _ photos: PhotoDrafts) -> Void
    let onClose: () -> Void
    @State private var note: String
    @State private var photos: PhotoDrafts

    init(
        editor: JournalEditor,
        isSaving: Bool,
        loader: @escaping PhotoLoader,
        onSave: @escaping (_ note: String, _ photos: PhotoDrafts) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.editor = editor
        self.isSaving = isSaving
        self.loader = loader
        self.onSave = onSave
        self.onClose = onClose
        _note = State(initialValue: editor.note)
        _photos = State(initialValue: PhotoDrafts(storedIDs: editor.photoIDs))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DSSpacing.m) {
                    JournalNoteField(placeholder: editor.labels.notePlaceholder, note: $note)
                    JournalPhotosField(photos: $photos, entry: editor.title, labels: editor.labels.photo, loader: loader)
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
                    // Saving ten photos takes a second or two: the button waits, and says so.
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(role: .confirm) { onSave(note, photos) }
                            .accessibilityLabel(editor.saveTitle)
                    }
                }
            }
        }
    }
}
