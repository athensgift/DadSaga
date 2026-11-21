import Foundation
import Presentation
import Testing

/// A quest or boss sheet's note and photos: what a swipe or Close would lose.
@Suite("Quest and boss sheets, unsaved note and photos")
struct JournalDraftTests {
    @Test("Given an empty note and no photos, when closing the sheet, then nothing is lost")
    func emptyHasNothingToLose() {
        #expect(!JournalDraft.hasUnsavedChanges(note: "", photos: PhotoDrafts()))
    }

    @Test("Given words in the note, when closing the sheet, then they would be lost")
    func noteIsSomethingToLose() {
        #expect(JournalDraft.hasUnsavedChanges(note: "Γέλασε", photos: PhotoDrafts()))
    }

    @Test("Given a picked photo, when closing the sheet, then it would be lost")
    func photoIsSomethingToLose() {
        var photos = PhotoDrafts()
        photos.append([Data([1, 2, 3])])

        #expect(JournalDraft.hasUnsavedChanges(note: "", photos: photos))
    }

    @Test("Given photos still arriving from the library, when closing the sheet, then they would be lost")
    func arrivingPhotosAreSomethingToLose() {
        var photos = PhotoDrafts()
        photos.startLoading(2)

        #expect(JournalDraft.hasUnsavedChanges(note: "", photos: photos))
    }
}
