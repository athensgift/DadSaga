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

    /// How far each mark is drawn grown, in the marks' order.
    func growths(_ sut: HomeViewModel) throws -> [Double] {
        try content(sut).skills.marks.map(\.growth)
    }

    /// How many times each mark has risen, by its id, leaving out the ones that never have.
    func rises(_ sut: HomeViewModel) throws -> [String: Int] {
        Dictionary(uniqueKeysWithValues: try content(sut).skills.marks.filter { $0.rises > 0 }.map { ($0.id, $0.rises) })
    }

    /// One quest of 20 care XP on the stub's curve, half grown at 80.
    static let oneQuest = 20.0 / 100.0

    @Test("Given a new dad, when home loads, then he is Level 0 and all four skills are there, in order, not grown")
    func newDad() async throws {
        let content = try content(await makeSUT())

        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
        #expect(content.dadTitle?.spoken == "Επίπεδο 0, Σε αναμονή")
        #expect(content.skills.marks.map(\.id) == ["care", "play", "patience", "resilience"])
        #expect(content.skills.marks.map(\.name) == ["Φροντίδα", "Παιχνίδι", "Υπομονή", "Αντοχή"])
        #expect(content.skills.marks.map(\.symbol) == ["heart.fill", "puzzlepiece.fill", "hourglass", "figure.mind.and.body"])
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 })
    }

    @Test("Given the skills row, when VoiceOver reads it, then it hears «Your skills» and the four names, no number")
    func voiceOver() async throws {
        let greek = try content(await makeSUT()).skills
        #expect(greek.label == "Οι δεξιότητές σου")
        #expect(greek.value == "Φροντίδα, Παιχνίδι, Υπομονή και Αντοχή")
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

    @Test("Given a care quest, when its celebration has gone, then only care's mark has grown, and more for a boss on top")
    func eachCardGrowsItsSkill() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.celebrationFinished(id: try #require(sut.celebration).id)

        let afterQuest = try growths(sut)
        #expect(abs(afterQuest[0] - Self.oneQuest) < 0.000_001)
        #expect(afterQuest.dropFirst().allSatisfy { $0 == 0 })

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        sut.celebrationFinished(id: try #require(sut.celebration).id)

        let afterBoss = try growths(sut)
        #expect(afterBoss[0] > afterQuest[0])
        #expect(afterBoss[0] < 1)
    }

    @Test("Given a quest just recorded, when its celebration shows and then goes, then its mark waits, and rises as it goes")
    func markWaitsForTheCelebration() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let celebration = try #require(sut.celebration)

        // The badge is on screen: the colour has not moved yet, so the badge never hides it rising.
        #expect(try growths(sut).allSatisfy { $0 == 0 })
        #expect(try rises(sut).isEmpty)
        // Not even if home is read again meanwhile.
        await sut.reload()
        #expect(try growths(sut).allSatisfy { $0 == 0 })

        sut.celebrationFinished(id: celebration.id)
        sut.celebrationFinished(id: celebration.id)

        #expect(abs(try growths(sut)[0] - Self.oneQuest) < 0.000_001)
        #expect(try rises(sut) == ["care": 1])
    }

    @Test("Given a quest just recorded, when it is undone under its celebration, then its mark never moved and nothing rises")
    func undoReturnsMarkAndLevel() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let celebration = try #require(sut.celebration)

        await sut.undoLastRecord()
        sut.celebrationFinished(id: celebration.id)

        let content = try content(sut)
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 && $0.rises == 0 })
        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
    }

    @Test("Given a quest whose mark has risen, when it is undone, then the mark is lower at once, with nothing rising")
    func undoAfterTheRiseLowersAtOnce() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.celebrationFinished(id: try #require(sut.celebration).id)
        #expect(try rises(sut) == ["care": 1])

        await sut.undoLastRecord()

        #expect(try growths(sut).allSatisfy { $0 == 0 })
        // The same count as before: the view animates only a change that comes with a new rise.
        #expect(try rises(sut) == ["care": 1])
    }

    @Test("Given a quest under its celebration, when undoing it fails, then its mark shows what it grew, with nothing rising")
    func failedUndoShowsTheGrowthAtOnce() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        await progress.failNext()

        await sut.undoLastRecord()

        #expect(await progress.eventCount == 1)
        #expect(sut.celebration == nil)
        #expect(abs(try growths(sut)[0] - Self.oneQuest) < 0.000_001)
        #expect(try rises(sut).isEmpty)
    }

    @Test("Given a quest whose mark waits, when an older entry of its skill is deleted meanwhile, then the mark is lower at once")
    func deletionLowersAWaitingMark() async throws {
        await progress.seed(times: 1)
        let sut = await makeSUT()
        let before = try growths(sut)[0]
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(try growths(sut)[0] == before)

        // As from the timeline: both care entries go.
        await progress.seed(times: 0)
        await sut.reload()

        #expect(try growths(sut)[0] == 0)
        #expect(try rises(sut).isEmpty)
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

    @Test("Given a boss celebrated, when its badge goes, then care's mark rises once, and again for the next card")
    func riseAsTheBadgeGoes() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        let boss = try #require(sut.celebration)
        #expect(try rises(sut).isEmpty)

        sut.celebrationFinished(id: boss.id)
        sut.celebrationFinished(id: boss.id)
        #expect(try rises(sut) == ["care": 1])
        let afterBoss = try growths(sut)[0]
        #expect(abs(afterBoss - 100.0 / 180.0) < 0.000_001)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(try growths(sut)[0] == afterBoss)
        sut.celebrationFinished(id: try #require(sut.celebration).id)
        #expect(try rises(sut) == ["care": 2])
        #expect(try growths(sut)[0] > afterBoss)
    }

    @Test("Given two care quests within seconds, when the badges go, then the mark rises once for each, a card at a time")
    func twoQuickCardsRiseOneAtATime() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        // The first badge went as the second came: the mark rose to where the first card took it, no further.
        #expect(abs(try growths(sut)[0] - Self.oneQuest) < 0.000_001)
        #expect(try rises(sut) == ["care": 1])

        sut.celebrationFinished(id: try #require(sut.celebration).id)
        #expect(abs(try growths(sut)[0] - 40.0 / 120.0) < 0.000_001)
        #expect(try rises(sut) == ["care": 2])
    }

    @Test("Given a care boss replaced by a play quest within seconds, when the badges go, then each mark rises once")
    func replacedCelebrationStillRises() async throws {
        let play = Quest(
            id: "q-play", worldID: "w1", title: LocalizedText(el: "Παιχνίδι", en: "Play"),
            description: LocalizedText(el: "δ", en: "d"), skill: .play, xp: 20, minAgeMonths: 0
        )
        let stub = HeroStub.catalog
        let catalog = ContentCatalog(
            worlds: stub.worlds, quests: stub.quests + [play], bosses: stub.bosses, firsts: stub.firsts,
            heroClasses: stub.heroClasses, gear: stub.gear, titles: stub.titles, skillCurves: stub.skillCurves
        )
        let sut = makeHomeViewModel(profile: HeroStub.profile, progress: progress, catalog: catalog)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        let boss = try #require(sut.celebration)
        sut.select(cardID: "q-play")
        await sut.completeSelectedQuest()
        // The boss's badge went as the quest's came: care's mark rises now, not never; play's still waits.
        #expect(try rises(sut) == ["care": 1])
        #expect(try growths(sut)[0] > 0)

        sut.celebrationFinished(id: boss.id)
        sut.celebrationFinished(id: try #require(sut.celebration).id)
        #expect(try rises(sut) == ["care": 1, "play": 1])
    }

    @Test("Given a quest's celebration, when a moment's replaces it as its sheet closes, then the quest's mark rises")
    func momentReplacesAQuest() async throws {
        let sut = await makeSUT()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.startCapture()
        await sut.captureMoment(firstID: "f1", date: HeroStub.today)
        #expect(try rises(sut).isEmpty)
        #expect(try growths(sut)[0] == 0)

        sut.dismissSelection()
        sut.sheetDismissed()

        #expect(sut.celebration?.momentText != nil)
        #expect(try rises(sut) == ["care": 1])
        #expect(try growths(sut)[0] > 0)
    }
}
