import DesignSystem
@testable import Presentation
import Testing

@Suite("Cover above the fold")
struct CoverAboveFoldTests {
    private let fold = HorizontalFold(top: 400, bottom: 430)

    @Test("Given photos on a half-open iPhone Duo, when the sheet is laid out, then the cover stands above the fold")
    func coverAboveTheFold() {
        let photos = PhotoDrafts(storedIDs: ["cover", "second"])
        #expect(photos.cover(above: fold)?.source == .stored("cover"))
    }

    @Test("Given no photo on a half-open iPhone Duo, when the sheet is laid out, then nothing waits above the fold")
    func noPhotoNothingAbove() {
        #expect(PhotoDrafts().cover(above: fold) == nil)
    }

    @Test("Given no fold across the sheet, when it is laid out, then the cover stays in the form")
    func flatKeepsTheCoverInTheForm() {
        #expect(PhotoDrafts(storedIDs: ["cover"]).cover(above: nil) == nil)
    }
}
