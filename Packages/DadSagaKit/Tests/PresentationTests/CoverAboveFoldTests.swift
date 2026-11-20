import DesignSystem
@testable import Presentation
import Testing

@Suite("Cover above the fold")
struct CoverAboveFoldTests {
    private let split = FoldedPanes.split(HorizontalFold(top: 400, bottom: 430))

    @Test("Given photos on a half-open iPhone Duo, when the sheet is laid out, then the cover has the upper pane")
    func coverAboveTheFold() {
        let photos = PhotoDrafts(storedIDs: ["cover", "second"])
        #expect(photos.cover(for: split)?.source == .stored("cover"))
    }

    @Test("Given no photo on a half-open iPhone Duo, when the sheet is laid out, then nothing waits above the fold")
    func noPhotoNothingAbove() {
        #expect(PhotoDrafts().cover(for: split) == nil)
    }

    @Test("Given a flat display, when the sheet is laid out, then the cover stays in the form")
    func flatKeepsTheCoverInTheForm() {
        #expect(PhotoDrafts(storedIDs: ["cover"]).cover(for: .flat) == nil)
    }

    @Test("Given the keyboard over the lower half, when the sheet is laid out, then the cover is not moved into the form")
    func keyboardKeepsTheCoverOutOfTheForm() {
        #expect(PhotoDrafts(storedIDs: ["cover"]).cover(for: .lowerOnly)?.source == .stored("cover"))
    }
}
