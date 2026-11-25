import Application
import Foundation
@testable import Presentation
import Testing

@Suite("Photo drafts")
struct PhotoDraftsTests {
    @Test("Given an entry's photos, when arranging nothing, then it keeps them all in order")
    func keepsStored() {
        let drafts = PhotoDrafts(storedIDs: ["a", "b"])
        #expect(drafts.entryPhotos == [.kept("a"), .kept("b")])
        #expect(drafts.pickedPhotos.isEmpty)
        #expect(drafts.remaining == 3)
        #expect(!drafts.isFull)
    }

    @Test("Given three photos, when three more are picked, then two are added after them and the field is full")
    func appendsWithinTheLimit() {
        var drafts = PhotoDrafts(storedIDs: (1...3).map { "p\($0)" })

        drafts.append([Data([1]), Data([2]), Data([3])])

        #expect(drafts.items.count == 5)
        #expect(drafts.isFull)
        #expect(drafts.remaining == 0)
        #expect(drafts.entryPhotos.suffix(2) == [.added(Data([1])), .added(Data([2]))])
        #expect(drafts.pickedPhotos == [Data([1]), Data([2])])
    }

    @Test("Given three photos, when making the last the cover, then it moves first and the others keep their order")
    func makesCover() throws {
        var drafts = PhotoDrafts(storedIDs: ["a", "b"])
        drafts.append([Data([9])])
        let picked = try #require(drafts.items.last?.id)

        drafts.makeCover(id: picked)

        #expect(drafts.entryPhotos == [.added(Data([9])), .kept("a"), .kept("b")])
        drafts.makeCover(id: "unknown")
        #expect(drafts.entryPhotos == [.added(Data([9])), .kept("a"), .kept("b")])
    }

    @Test("Given a full field, when removing one, then there is room for one more and the rest stay in order")
    func removes() {
        var drafts = PhotoDrafts(storedIDs: (1...5).map { "p\($0)" })

        drafts.remove(id: "p1")

        #expect(drafts.remaining == 1)
        #expect(drafts.entryPhotos.first == .kept("p2"))
        #expect(drafts.items.count == 4)
    }

    @Test("Given a stored photo, when two equal photos are picked, then each has its own id")
    func pickedIDs() {
        var drafts = PhotoDrafts(storedIDs: ["a"])
        drafts.append([Data([1]), Data([1])])
        #expect(Set(drafts.items.map(\.id)).count == 3)
    }

    @Test("Given three photos, when three are still loading, then only two fit, it counts as changed, and finishing adds them")
    func loading() {
        let stored = PhotoDrafts(storedIDs: (1...3).map { "p\($0)" })
        var drafts = stored

        drafts.startLoading(3)

        #expect(drafts.isLoading)
        #expect(drafts.loadingCount == 2)
        #expect(drafts.isFull)
        #expect(drafts != stored)
        drafts.finishLoading([Data([1]), Data([2]), Data([3])])
        #expect(!drafts.isLoading)
        #expect(drafts.items.count == 5)
    }

    @Test("Given photos loading, when the loading is given up, then nothing is added and the room comes back")
    func loadingGivenUp() {
        var drafts = PhotoDrafts(storedIDs: ["a"])
        drafts.startLoading(4)

        drafts.finishLoading()

        #expect(drafts == PhotoDrafts(storedIDs: ["a"]))
        #expect(drafts.remaining == 4)
    }

    @Test("Given three photos picked, when one can't be read, then two are added and one is reported left out")
    func unreadPhotosAreReported() {
        var drafts = PhotoDrafts()
        drafts.startLoading(3)

        let leftOut = drafts.finishLoading([Data([1]), Data([2])], picked: 3)

        #expect(drafts.items.count == 2)
        #expect(leftOut == 1)
    }

    @Test("Given a photo picked that can't be read, when the reading ends, then the entry is as it was: nothing to save")
    func nothingReadableIsNoChange() {
        var drafts = PhotoDrafts(storedIDs: ["a"])
        drafts.startLoading(1)

        let leftOut = drafts.finishLoading([], picked: 1)

        #expect(leftOut == 1)
        #expect(drafts == PhotoDrafts(storedIDs: ["a"]))
    }

    @Test("Given photos loading, when the reading is given up, then nothing is reported left out")
    func givenUpReportsNothing() {
        var drafts = PhotoDrafts()
        drafts.startLoading(2)

        #expect(drafts.finishLoading() == 0)
    }

    @Test("Given photos that couldn't be opened, when the field says so, then it counts them in Greek and English")
    func couldNotOpenMessage() {
        let greek = PhotoLabels(locale: Locale(identifier: "el_GR"))
        let english = PhotoLabels(locale: Locale(identifier: "en_US"))

        #expect(greek.couldNotOpen(1) == "1 φωτογραφία δεν άνοιξε. Αν είναι στο iCloud, δοκίμασε ξανά σε λίγο.")
        #expect(greek.couldNotOpen(2) == "2 φωτογραφίες δεν άνοιξαν. Αν είναι στο iCloud, δοκίμασε ξανά σε λίγο.")
        #expect(english.couldNotOpen(1) == "1 photo couldn't be opened. If it's in iCloud, try again in a moment.")
        #expect(english.couldNotOpen(3) == "3 photos couldn't be opened. If they're in iCloud, try again in a moment.")
    }

    @Test("Given a camera photo that couldn't be kept, when the field says so, then it says it in Greek and English")
    func couldNotKeepShotMessage() {
        #expect(PhotoLabels(locale: Locale(identifier: "el_GR")).couldNotKeepShot == "Η φωτογραφία δεν κρατήθηκε. Τράβηξέ την ξανά.")
        #expect(PhotoLabels(locale: Locale(identifier: "en_US")).couldNotKeepShot == "That photo couldn't be kept. Please take it again.")
    }

    @Test("Given a square of 64 points at 3x, when a photo fills it, then it is asked for once, large enough for a 16:9 photo")
    func fillingPixelSize() {
        // 64 pt × 3 = 192 px for the short side; a 16:9 photo's long side is then 342 px.
        #expect(PhotoFill.pixelSize(filling: CGSize(width: 64, height: 64), scale: 3) == 342)
        #expect(PhotoFill.pixelSize(filling: .zero, scale: 3) == 0)
    }
}
