/// A new entry's note and photos, while a quest or boss sheet is open: what a swipe or Close would lose
/// (`UnsavedChangesGuard`).
public enum JournalDraft {
    /// Words written, photos picked, or photos still arriving from the library.
    public static func hasUnsavedChanges(note: String, photos: PhotoDrafts) -> Bool {
        !note.isEmpty || !photos.isEmpty || photos.isLoading
    }
}
