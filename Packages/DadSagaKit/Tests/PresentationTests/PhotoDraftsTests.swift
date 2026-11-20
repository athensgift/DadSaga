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
        #expect(drafts.remaining == 8)
        #expect(!drafts.isFull)
    }

    @Test("Given eight photos, when three more are picked, then two are added after them and the field is full")
    func appendsWithinTheLimit() {
        var drafts = PhotoDrafts(storedIDs: (1...8).map { "p\($0)" })

        drafts.append([Data([1]), Data([2]), Data([3])])

        #expect(drafts.items.count == 10)
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
        var drafts = PhotoDrafts(storedIDs: (1...10).map { "p\($0)" })

        drafts.remove(id: "p1")

        #expect(drafts.remaining == 1)
        #expect(drafts.entryPhotos.first == .kept("p2"))
        #expect(drafts.items.count == 9)
    }

    @Test("Given a stored photo, when two equal photos are picked, then each has its own id")
    func pickedIDs() {
        var drafts = PhotoDrafts(storedIDs: ["a"])
        drafts.append([Data([1]), Data([1])])
        #expect(Set(drafts.items.map(\.id)).count == 3)
    }

    @Test("Given eight photos, when three are still loading, then only two fit, it counts as changed, and finishing adds them")
    func loading() {
        let stored = PhotoDrafts(storedIDs: (1...8).map { "p\($0)" })
        var drafts = stored

        drafts.startLoading(3)

        #expect(drafts.isLoading)
        #expect(drafts.loadingCount == 2)
        #expect(drafts.isFull)
        #expect(drafts != stored)
        drafts.finishLoading([Data([1]), Data([2]), Data([3])])
        #expect(!drafts.isLoading)
        #expect(drafts.items.count == 10)
    }

    @Test("Given photos loading, when the loading is given up, then nothing is added and the room comes back")
    func loadingGivenUp() {
        var drafts = PhotoDrafts(storedIDs: ["a"])
        drafts.startLoading(4)

        drafts.finishLoading()

        #expect(drafts == PhotoDrafts(storedIDs: ["a"]))
        #expect(drafts.remaining == 9)
    }
}
