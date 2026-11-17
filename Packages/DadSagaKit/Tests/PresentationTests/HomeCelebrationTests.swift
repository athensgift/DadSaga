import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, celebrations")
struct HomeCelebrationTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile?) -> HomeViewModel {
        makeHomeViewModel(profile: profile, progress: progress)
    }

    @Test("Given 80 XP, when completing a quest, then the celebration announces the new level")
    func levelUpCelebration() async {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.levelUpText == "Επίπεδο 2!")
        #expect(sut.celebration?.highlight == .levelUp)
    }
}
