import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, photos on quests and bosses")
struct HomeJournalPhotosTests {
    let progress = FakeProgress()

    @Test("Given picked photos, when completing a quest and beating a boss, then each is recorded with its photos in order")
    func recordsPickedPhotos() async {
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress)
        await sut.onAppear()
        var photos = PhotoDrafts()
        photos.append([Data([1]), Data([2])])
        photos.makeCover(id: photos.items[1].id)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest(note: "", photos: photos)
        sut.select(cardID: "b1")
        var bossPhotos = PhotoDrafts()
        bossPhotos.append([Data([3])])
        await sut.defeatSelectedBoss(note: "", photos: bossPhotos)

        #expect(await progress.recordedPhotos == [[Data([2]), Data([1])], [Data([3])]])
        #expect(sut.selectedQuest == nil)
        #expect(sut.selectedBoss == nil)
    }
}
