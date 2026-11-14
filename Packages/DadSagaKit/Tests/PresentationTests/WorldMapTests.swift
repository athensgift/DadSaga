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
                             minAgeMonths: 0, maxAgeMonths: 8)
    static let plains = World(id: "w2", order: 2, title: LocalizedText(el: "Πεδιάδα", en: "Plains"), tagline: text,
                              minAgeMonths: 9, maxAgeMonths: 24)
    static let land = World(id: "w3", order: 3, title: LocalizedText(el: "Χώρα", en: "Land"), tagline: text,
                            minAgeMonths: 25, maxAgeMonths: 41)
    static let swampQuest = Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)
    static let plainsQuest = Quest(id: "q2", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 9)
    static let catalog = ContentCatalog(
        worlds: [swamp, plains, land],
        quests: [swampQuest, plainsQuest],
        bosses: [],
        firsts: HeroStub.catalog.firsts
    )

    /// A child of `months` whose current world is the latest one unlocked.
    func makeSUT(ageInMonths months: Int, profile: PlayerProfile = HeroStub.profile) -> HomeViewModel {
        let unlocked = Self.catalog.worlds.filter { $0.minAgeMonths <= months }
        return HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getProfile: StubGetProfile(profile: profile),
                loadCatalog: StubLoadCatalog(result: .success(Self.catalog)),
                getAdventure: FixedAdventure(
                    adventure: Adventure(
                        ageInMonths: months,
                        currentWorld: unlocked.last,
                        unlockedWorlds: unlocked,
                        availableQuests: Self.catalog.quests.filter { $0.minAgeMonths <= months },
                        availableBosses: []
                    )
                ),
                getProgress: progress,
                completeQuest: progress,
                defeatBoss: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, delete: progress, getPhoto: progress)
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

    @Test("Given a 10-month-old, when opening the map, then worlds show status, age ranges, progress and unlock time")
    func opensMap() async throws {
        let sut = makeSUT(ageInMonths: 10)
        await sut.onAppear()

        sut.openMap()

        let map = try #require(sut.worldMap)
        #expect(map.title == "Χάρτης κόσμων")
        #expect(map.subtitle == "Νίκος · 10 μηνών")
        #expect(map.worlds.map(\.status) == [WorldMapItem.Status.visited, .current, .locked])
        #expect(map.worlds.map(\.ageRange) == ["0–8 μηνών", "9–24 μηνών", "2–3½ ετών"])
        #expect(map.worlds.map(\.tag) == [nil, "Είσαι εδώ", nil])
        #expect(map.worlds[0].detail == "0 / 1 αποστολές · 0 / 0 αφεντικά")
        #expect(map.worlds[2].detail == "Ξεκλειδώνει σε 15 μήνες")
        #expect(loaded(sut)?.mapTitle == "Χάρτης κόσμων")
    }

    @Test("Given an earlier world, when showing it, then home shows its quests with a way back, until going back")
    func showsEarlierWorld() async throws {
        let sut = makeSUT(ageInMonths: 10)
        await sut.onAppear()
        #expect(loaded(sut)?.cards.map(\.id) == ["q2"])
        sut.openMap()

        await sut.showWorld(id: "w1")

        #expect(sut.worldMap == nil)
        #expect(loaded(sut)?.worldTitle == "Βάλτος")
        #expect(loaded(sut)?.cards.map(\.id) == ["q1"])
        #expect(loaded(sut)?.backToCurrentTitle == "Πίσω στον κόσμο του τώρα")
        sut.openMap()
        #expect(sut.worldMap?.worlds.first?.isShown == true)
        #expect(sut.worldMap?.worlds.first?.tag == "Το βλέπεις τώρα")

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.openMap()
        #expect(sut.worldMap?.worlds.first?.detail == "1 / 1 αποστολές · 0 / 0 αφεντικά")

        await sut.showWorld(id: nil)
        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.cards.map(\.id) == ["q2"])
    }

    @Test("Given a locked world, when trying to show it, then nothing changes")
    func lockedWorld() async throws {
        let sut = makeSUT(ageInMonths: 10)
        await sut.onAppear()

        await sut.showWorld(id: "w3")

        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.worldTitle == "Πεδιάδα")
    }

    @Test("Given an earlier world is shown, when choosing another child, then the current world is shown again")
    func childResetsWorld() async throws {
        let sut = makeSUT(ageInMonths: 10, profile: HeroStub.family)
        await sut.onAppear()
        await sut.showWorld(id: "w1")

        await sut.selectChild(id: HeroStub.eleni.id)

        #expect(loaded(sut)?.backToCurrentTitle == nil)
        #expect(loaded(sut)?.worldTitle == "Πεδιάδα")
    }
}

struct FixedAdventure: GetAdventureUseCase {
    let adventure: Adventure

    func execute(for child: Child, on date: Date) async throws -> Adventure {
        adventure
    }
}
