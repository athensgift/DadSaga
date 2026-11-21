import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, quest tips and evergreen quests")
struct QuestTipsTests {
    let progress = FakeProgress()

    static let text = HeroStub.text
    static let swamp = World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8))
    static let plains = World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24))
    static let tip = QuestTip(
        title: LocalizedText(el: "Ο καναπές είναι παγίδα", en: "The sofa is a trap"),
        steps: [LocalizedText(el: "Βήμα ένα", en: "Step one"), LocalizedText(el: "Βήμα δύο", en: "Step two")],
        isMedical: true
    )
    static let evergreen = Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20,
                                 minAgeMonths: 0, tip: tip, isEvergreen: true)
    static let plainsQuest = Quest(id: "q2", worldID: "w2", title: text, description: text, skill: .play, xp: 20,
                                   minAgeMonths: 9)
    static let catalog = ContentCatalog(
        worlds: [swamp, plains],
        quests: [evergreen, plainsQuest],
        bosses: [],
        firsts: HeroStub.catalog.firsts
    )

    func makeSUT() -> HomeViewModel {
        let adventure = Adventure(
            age: .months(10), family: .everyone, currentWorld: Self.plains, unlockedWorlds: [Self.swamp, Self.plains]
        )
        return HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: FakeHomeOverview(profile: HeroStub.profile, catalog: Self.catalog, progress: progress) { _ in
                    adventure
                },
                completeQuest: progress,
                defeatBoss: progress,
                deleteEvent: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
                reminder: .neverOffered,
                answerSagaOffer: FakeFilmOffers(),
                markTitleSeen: FakeTitleSeen()
            ),
            locale: Locale(identifier: "el_GR"),
            now: { HeroStub.today }
        )
    }

    func cards(_ sut: HomeViewModel) -> [CardModel] {
        guard case .loaded(let content) = sut.state else { return [] }
        return content.cards
    }

    @Test("Given an evergreen quest from an earlier world, when appearing, then it follows the current world's quests")
    func evergreenOnHome() async {
        let sut = makeSUT()
        await sut.onAppear()
        #expect(cards(sut).map(\.id) == ["q2", "q1"])
    }

    @Test("Given a quest with a tip, when showing its card, then the card is marked with the tip's title")
    func cardMarker() async {
        let sut = makeSUT()
        await sut.onAppear()
        #expect(cards(sut).map(\.hint) == [nil, "Ο καναπές είναι παγίδα"])
    }

    @Test("Given a medical tip, when opening the quest, then the steps and the doctor footer are shown")
    func medicalTip() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        sut.select(cardID: "q1")

        let quest = try #require(sut.selectedQuest)
        #expect(quest.tip?.title == "Ο καναπές είναι παγίδα")
        #expect(quest.tip?.steps == ["Βήμα ένα", "Βήμα δύο"])
        #expect(quest.footer == "Γενικές πληροφορίες. Δεν αντικαθιστούν τη συμβουλή γιατρού.")
    }

    @Test("Given a quest without a tip, when opening it, then there is no tip and no footer")
    func noTip() async throws {
        let sut = makeSUT()
        await sut.onAppear()

        sut.select(cardID: "q2")

        let quest = try #require(sut.selectedQuest)
        #expect(quest.tip == nil)
        #expect(quest.footer == nil)
    }

    @Test("Given an evergreen quest done in a later world, when opening the map, then it counts only in its home world")
    func evergreenCountsAtHome() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        sut.openMap()

        let map = try #require(sut.worldMap)
        #expect(map.worlds.map(\.detail) == ["1 αποστολή · 0 αφεντικά", "0 αποστολές · 0 αφεντικά"])
    }
}
