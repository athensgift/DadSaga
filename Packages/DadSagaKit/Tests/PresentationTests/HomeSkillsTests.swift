import Domain
import Foundation
import Presentation
import Testing

/// Home's title line with its level, and the dad's four skills under it (ADR-0059).
@MainActor
@Suite("HomeViewModel, level and skills")
struct HomeSkillsTests {
    let progress = FakeProgress()

    func makeSUT(locale: String = "el_GR") async -> HomeViewModel {
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress, locale: locale)
        await sut.onAppear()
        return sut
    }

    func content(_ sut: HomeViewModel) throws -> HomeContent {
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        return content
    }

    @Test("Given a new dad, when home loads, then he is Level 0 and all four skills are there, in order, not grown")
    func newDad() async throws {
        let content = try content(await makeSUT())

        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
        #expect(content.dadTitle?.spoken == "Επίπεδο 0, Σε αναμονή")
        #expect(content.skills.marks.map(\.skill) == [.care, .play, .patience, .resilience])
        #expect(content.skills.marks.map(\.name) == ["Φροντίδα", "Παιχνίδι", "Υπομονή", "Αντοχή"])
        #expect(content.skills.marks.map(\.symbol) == ["heart.fill", "puzzlepiece.fill", "hourglass", "figure.mind.and.body"])
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 })
    }

    @Test("Given the skills row, when VoiceOver reads it, then it hears «Your skills» and the four names, no number")
    func voiceOver() async throws {
        let greek = try content(await makeSUT()).skills
        #expect(greek.label == "Οι δεξιότητές σου")
        let names = ["Φροντίδα", "Παιχνίδι", "Υπομονή", "Αντοχή"]
        #expect(greek.value == names.formatted(.list(type: .and).locale(Locale(identifier: "el_GR"))))
        let english = try content(await makeSUT(locale: "en_US")).skills
        #expect(english.label == "Your skills")
        #expect(english.value == "Care, Play, Patience, and Resilience")
        for text in [greek.label, greek.value, english.label, english.value] {
            #expect(!text.contains { $0.isNumber }, "\(text)")
        }
    }

    @Test("Given an English locale, when the first quest brings a title, then the line reads its level and name")
    func english() async throws {
        let sut = await makeSUT(locale: "en_US")
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        let title = try #require(try content(sut).dadTitle)
        #expect(title.text == "Level 1 · New to the journey")
        #expect(title.spoken == "Level 1, New to the journey")
        #expect(sut.titleCard?.level == "Level 1")
    }

    @Test("Given a care quest, when it is recorded, then only care's mark grows, and more for a boss on top")
    func eachCardGrowsItsSkill() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        let afterQuest = try content(sut).skills.marks.map(\.growth)
        #expect(abs(afterQuest[0] - 0.2) < 0.000_001)
        #expect(afterQuest.dropFirst().allSatisfy { $0 == 0 })

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()

        let afterBoss = try content(sut).skills.marks.map(\.growth)
        #expect(afterBoss[0] > afterQuest[0])
        #expect(afterBoss[0] < 1)
    }

    @Test("Given a quest just recorded, when it is undone, then its mark is back where it was, and the level stays")
    func undoShrinksTheMarkNotTheLevel() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        await sut.undoLastRecord()

        let content = try content(sut)
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 })
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
        // An undone card bounces nothing: its celebration never finished.
        #expect(sut.skillBounces.isEmpty)
    }

    @Test("Given a first captured, when home loads, then it counts toward the title but grows no skill")
    func firstGrowsNoSkill() async throws {
        let sut = await makeSUT()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)

        let content = try content(sut)
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 })
    }

    @Test("Given a boss celebrated, when its badge goes, then care's mark bounces once, and again for the next card")
    func bounceAsTheBadgeGoes() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        let boss = try #require(sut.celebration)
        #expect(boss.grownSkill == .care)
        #expect(sut.skillBounces.isEmpty)

        sut.celebrationFinished(id: boss.id)
        sut.celebrationFinished(id: boss.id)
        #expect(sut.skillBounces == [.care: 1])

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.celebrationFinished(id: try #require(sut.celebration).id)
        #expect(sut.skillBounces == [.care: 2])
    }
}
