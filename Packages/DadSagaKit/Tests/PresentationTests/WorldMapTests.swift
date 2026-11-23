import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, world map")
struct WorldMapTests {
    let progress = FakeProgress()

    static let text = HeroStub.text
    static let swamp = World(id: "w1", order: 1, title: LocalizedText(el: "Βάλτος", en: "Swamp"), tagline: text,
                             span: .months(min: 0, max: 8))
    static let plains = World(id: "w2", order: 2, title: LocalizedText(el: "Πεδιάδα", en: "Plains"), tagline: text,
                              span: .months(min: 9, max: 24))
    static let land = World(id: "w3", order: 3, title: LocalizedText(el: "Χώρα", en: "Land"), tagline: text,
                            span: .months(min: 25, max: 41))
    static let swampQuest = Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)
    static let plainsQuest = Quest(id: "q2", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 9)
    static let plainsLateQuest = Quest(id: "q2-late", worldID: "w2", title: text, description: text, skill: .play, xp: 20,
                                       minAgeMonths: 18)
    static let landQuest = Quest(id: "q3", worldID: "w3", title: text, description: text, skill: .care, xp: 20,
                                 minAgeMonths: 30)
    static let landRetired = Quest(id: "q3-old", worldID: "w3", title: text, description: text, skill: .care, xp: 20,
                                   minAgeMonths: 25, isRetired: true)
    static let landBoss = BossFight(id: "b3", worldID: "w3", title: text, intro: text, guide: [text], badge: text,
                                    skill: .care, xp: 100, minAgeMonths: 36)
    static let catalog = ContentCatalog(
        worlds: [swamp, plains, land],
        quests: [swampQuest, plainsQuest, plainsLateQuest, landQuest, landRetired],
        bosses: [landBoss],
        firsts: HeroStub.catalog.firsts
    )

    /// A child of `months` whose current world is the latest one reached.
    func makeSUT(months: Int, profile: PlayerProfile = HeroStub.profile) -> HomeViewModel {
        let reached = UnlockRules.reachedWorlds(in: Self.catalog, age: .months(months))
        let adventure = Adventure(
            age: .months(months), family: .everyone, currentWorld: reached.last, reachedWorlds: reached
        )
        return HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: FakeHomeOverview(profile: profile, catalog: Self.catalog, progress: progress) { _ in adventure },
                completeQuest: progress,
                defeatBoss: progress,
                deleteEvent: progress,
                undoRecord: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
                reminder: .neverOffered,
                answerSagaOffer: FakeFilmOffers(),
                markTitleSeen: FakeTitleSeen()
            ),
            locale: Locale(identifier: "el_GR"),
            now: { HeroStub.today }
        )
    }

    func loaded(_ sut: HomeViewModel) -> HomeContent? {
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return nil
        }
        return content
    }

    @Test("Given a 10-month-old, when home loads, then the map shows each world's status, ages, progress and ideal start")
    func mapLoadsWithHome() async throws {
        let sut = makeSUT(months: 10)
        await sut.onAppear()

        let map = try #require(sut.worldMap)
        #expect(map.title == "Χάρτης κόσμων")
        #expect(map.subtitle == "Νίκος · 10 μηνών")
        #expect(map.openTitle == "Άνοιξε αυτόν τον κόσμο")
        #expect(map.worlds.map(\.status) == [WorldMapItem.Status.visited, .current, .ahead])
        #expect(map.worlds.map(\.ageRange) == ["0–8 μηνών", "9–24 μηνών", "2–3½ ετών"])
        #expect(map.worlds.map(\.tag) == [nil, "Είσαι εδώ", nil])
        #expect(map.worlds.map(\.progress) == ["0 αποστολές · 0 αφεντικά", "0 αποστολές · 0 αφεντικά", nil])
        #expect(map.worlds.map(\.idealLine) == [nil, nil, "Ιδανικά από τα 2 χρόνια"])
        #expect(map.shownWorld?.id == "w2")
    }

    @Test("Given an earlier world, when showing it, then home shows its quests with a way back, until going back")
    func showsEarlierWorld() async throws {
        let sut = makeSUT(months: 10)
        await sut.onAppear()
        #expect(loaded(sut)?.cards.map(\.id) == ["q2"])

        await sut.showWorld(id: "w1")

        #expect(loaded(sut)?.worldTitle == "Βάλτος")
        #expect(loaded(sut)?.cards.map(\.id) == ["q1"])
        #expect(loaded(sut)?.backToCurrentTitle == "Πίσω στον τωρινό κόσμο")
        #expect(loaded(sut)?.idealLine == nil)
        #expect(sut.worldMap?.worlds.first?.isShown == true)
        #expect(sut.worldMap?.worlds.first?.tag == "Σε προβολή")
        #expect(sut.worldMap?.shownWorld?.id == "w1")

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(sut.worldMap?.worlds.first?.progress == "1 αποστολή · 0 αφεντικά")

        await sut.showWorld(id: nil)
        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.cards.map(\.id) == ["q2"])
    }

    @Test("Given a world ahead, when showing it, then home offers all its cards whatever their ages, and says when it is ideal")
    func showsWorldAhead() async throws {
        let sut = makeSUT(months: 10)
        await sut.onAppear()

        await sut.showWorld(id: "w3")

        #expect(loaded(sut)?.worldTitle == "Χώρα")
        #expect(loaded(sut)?.cards.map(\.id) == ["q3", "b3"])
        #expect(loaded(sut)?.idealLine == "Ιδανικά από τα 2 χρόνια")
        #expect(loaded(sut)?.backToCurrentTitle == "Πίσω στον τωρινό κόσμο")
        #expect(sut.worldMap?.worlds.last?.tag == "Σε προβολή")
    }

    @Test("Given the current world, when home shows it, then its own cards still come with the child's age")
    func currentWorldKeepsItsPace() async throws {
        let sut = makeSUT(months: 10)
        await sut.onAppear()

        #expect(loaded(sut)?.cards.map(\.id) == ["q2"])
        #expect(loaded(sut)?.idealLine == nil)
    }

    @Test("Given a world the catalog doesn't have, when trying to show it, then nothing changes")
    func unknownWorld() async throws {
        let sut = makeSUT(months: 10)
        await sut.onAppear()

        await sut.showWorld(id: "w9")

        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.worldTitle == "Πεδιάδα")
    }

    @Test("Given another world is shown, when choosing another child, then the current world is shown again")
    func childResetsWorld() async throws {
        let sut = makeSUT(months: 10, profile: HeroStub.family)
        await sut.onAppear()
        await sut.showWorld(id: "w3")

        await sut.selectChild(id: HeroStub.eleni.id)

        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.worldTitle == "Πεδιάδα")
        #expect(sut.worldMap?.subtitle.hasPrefix(HeroStub.eleni.name) == true)
    }
}
