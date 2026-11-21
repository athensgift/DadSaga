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

    @Test("Given 80 XP, when completing a quest with VoiceOver on, then what it hears says the XP and the new level")
    func celebrationIsReadOut() async {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.announcement == "+20 XP, Επίπεδο 2!")
    }

    @Test("Given a level-up and a plain quest, when haptics are on, then the level-up taps and the plain quest does not")
    func hapticsOn() async throws {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let levelUp = try #require(sut.celebration)
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let plain = try #require(sut.celebration)

        #expect(levelUp.haptic(isEnabled: true) == .success)
        #expect(plain.highlight == .quest)
        #expect(plain.haptic(isEnabled: true) == nil)
    }

    @Test("Given haptics are off, when a level-up is celebrated, then nothing taps")
    func hapticsOff() async throws {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(try #require(sut.celebration).haptic(isEnabled: false) == nil)
    }
}
