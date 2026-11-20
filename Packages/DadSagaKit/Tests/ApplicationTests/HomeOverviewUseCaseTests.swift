import Application
import Domain
import Foundation
import Testing

@Suite("GetHomeOverviewUseCase")
struct HomeOverviewUseCaseTests {
    static let text = Stub.text
    static let swamp = World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: 8)
    static let plains = World(id: "w2", order: 2, title: text, tagline: text, minAgeMonths: 9, maxAgeMonths: 24)
    static let catalog = ContentCatalog(
        worlds: [swamp, plains],
        quests: [
            Quest(id: "q-evergreen", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                  isEvergreen: true),
            Quest(id: "q-swamp", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q-plains", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 9),
            Quest(id: "q-later", worldID: "w2", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 20)
        ],
        bosses: [
            BossFight(id: "b-swamp", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0),
            BossFight(id: "b-plains", worldID: "w2", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 9),
            BossFight(id: "b-together", worldID: "w2", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 9, requiresSibling: true)
        ],
        firsts: [],
        gear: [
            GearItem(id: "g-cloth", skill: .care, minXP: 20, look: "burpCloth", title: text),
            GearItem(id: "g-duck", skill: .play, minXP: 500, look: "duck", title: text)
        ]
    )

    let today = Date(timeIntervalSince1970: 400 * 86_400)
    var baby: Child { Child(name: "Νίκος", birthDate: today.addingTimeInterval(-60 * 86_400)) }
    var toddler: Child { Child(name: "Ελένη", birthDate: today.addingTimeInterval(-365 * 86_400)) }
    let profiles = SpyProfileRepository()
    let progress = SpyProgressRepository()
    let outfit = SpyOutfitRepository()
    let offers = FakeSagaOffers()
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    var sut: DefaultGetHomeOverviewUseCase {
        DefaultGetHomeOverviewUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            outfitRepository: outfit,
            sagaOfferRepository: offers,
            calendar: Self.utc
        )
    }

    func family(_ children: [Child]) async throws {
        try await profiles.save(PlayerProfile(children: children, heroClassID: "h"))
    }

    @Test("Given no family yet, when reading home, then there is nothing to show")
    func noFamily() async throws {
        #expect(try await sut.execute(childID: nil, worldID: nil, on: today) == nil)
    }

    @Test("Given two children and no choice, or a child no longer in the family, when reading home, then the first shows")
    func childFallsBackToFirst() async throws {
        let baby = baby
        try await family([baby, toddler])

        #expect(try await sut.execute(childID: nil, worldID: nil, on: today)?.child == baby)
        #expect(try await sut.execute(childID: UUID(), worldID: nil, on: today)?.child == baby)
    }

    @Test("Given a toddler, when reading home, then the current world's quests for the age and the evergreen ones show")
    func currentWorld() async throws {
        let toddler = toddler
        try await family([baby, toddler])

        let overview = try #require(try await sut.execute(childID: toddler.id, worldID: nil, on: today))

        #expect(overview.child == toddler)
        #expect(overview.shownWorld == Self.plains)
        #expect(overview.isShowingCurrentWorld)
        #expect(overview.quests.map(\.id) == ["q-plains", "q-evergreen"])
        #expect(overview.bosses.map(\.id) == ["b-plains", "b-together"])
    }

    @Test("Given an earlier world chosen on the map, when reading home, then that world's quests and bosses show")
    func earlierWorld() async throws {
        try await family([toddler])

        let overview = try #require(try await sut.execute(childID: nil, worldID: "w1", on: today))

        #expect(overview.shownWorld == Self.swamp)
        #expect(!overview.isShowingCurrentWorld)
        #expect(overview.quests.map(\.id) == ["q-evergreen", "q-swamp"])
        #expect(overview.bosses.map(\.id) == ["b-swamp"])
    }

    @Test("Given a world the child has not reached, when reading home, then the current world shows instead")
    func lockedWorldIgnored() async throws {
        try await family([baby])

        let overview = try #require(try await sut.execute(childID: nil, worldID: "w2", on: today))

        #expect(overview.shownWorld == Self.swamp)
        #expect(overview.isShowingCurrentWorld)
    }

    @Test("Given earned gear, when reading home, then the hero wears it unless the dad chose nothing for that slot")
    func gearFollowsOutfit() async throws {
        let baby = baby
        try await family([baby])
        try await progress.add(ProgressEvent(kind: .quest(id: "q-swamp"), childID: baby.id, date: today))

        #expect(try await sut.execute(childID: nil, worldID: nil, on: today)?.equippedGear.map(\.id) == ["g-cloth"])

        _ = try await outfit.setChoice(.hidden, for: .care)
        #expect(try await sut.execute(childID: nil, worldID: nil, on: today)?.equippedGear.isEmpty == true)
    }

    @Test("Given one child or two, when reading home in the plains, then a sibling boss shows only with two")
    func siblingBoss() async throws {
        let toddler = toddler
        try await family([toddler])
        #expect(try await sut.execute(childID: nil, worldID: nil, on: today)?.bosses.map(\.id) == ["b-plains"])

        try await family([toddler, baby])
        let overview = try #require(try await sut.execute(childID: toddler.id, worldID: nil, on: today))
        #expect(overview.childCount == 2)
        #expect(overview.bosses.map(\.id) == ["b-plains", "b-together"])
    }

    @Test("Given a child older than every world, when reading home with or without a chosen world, then the choice decides")
    func beyondContent() async throws {
        let older = Child(name: "Άννα", birthDate: today.addingTimeInterval(-3 * 365 * 86_400))
        try await family([older])

        let current = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(current.adventure.isBeyondContent)
        #expect(current.shownWorld == nil)
        #expect(current.isShowingCurrentWorld)
        #expect(current.quests.isEmpty)

        let chosen = try #require(try await sut.execute(childID: nil, worldID: "w1", on: today))
        #expect(chosen.shownWorld == Self.swamp)
        #expect(!chosen.isShowingCurrentWorld)
        #expect(chosen.bosses.isEmpty)
    }

    @Test("Given a boss beaten with one child, when reading home for each child, then it is defeated only for that child")
    func defeatedPerChild() async throws {
        let baby = baby
        let toddler = toddler
        try await family([baby, toddler])
        try await progress.add(ProgressEvent(kind: .boss(id: "b-plains"), childID: toddler.id, date: today))

        #expect(try await sut.execute(childID: toddler.id, worldID: nil, on: today)?.defeatedBossIDs == ["b-plains"])
        #expect(try await sut.execute(childID: baby.id, worldID: nil, on: today)?.defeatedBossIDs.isEmpty == true)
    }

    @Test("Given no events, when reading home, then the dad is level 1 with 0 XP")
    func emptyProgress() async throws {
        try await family([baby])
        let overview = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(overview.progress.totalXP == 0)
        #expect(overview.progress.level.level == 1)
    }

    // MARK: The film offer

    /// Turned one `days` ago.
    func oneYearOld(for days: Double, name: String = "Άννα") -> Child {
        Child(name: name, birthDate: today.addingTimeInterval(-(365 + days) * 86_400))
    }

    func quest(with child: Child, daysAgo: Double) -> ProgressEvent {
        ProgressEvent(kind: .quest(id: "q-swamp"), childID: child.id, date: today.addingTimeInterval(-daysAgo * 86_400))
    }

    @Test("Given a first birthday five days ago and a quest in that year, when reading home, then its film is offered")
    func offersTheBirthdayFilm() async throws {
        let anna = oneYearOld(for: 5)
        try await family([anna])
        try await progress.add(quest(with: anna, daysAgo: 100))

        let offer = try #require(try await sut.execute(childID: nil, worldID: nil, on: today)?.sagaOffer)

        #expect(offer.childID == anna.id)
        #expect(offer.kind == .birthday(years: 1))
        #expect(offer.period == .year(1))
    }

    @Test("Given home shows the baby, when his sister had a birthday five days ago, then her film is offered all the same")
    func offersForTheWholeFamily() async throws {
        let baby = baby
        let anna = oneYearOld(for: 5)
        try await family([baby, anna])
        try await progress.add(quest(with: anna, daysAgo: 100))

        let overview = try #require(try await sut.execute(childID: baby.id, worldID: nil, on: today))

        #expect(overview.child == baby)
        #expect(overview.sagaOffer?.childID == anna.id)
    }

    @Test("Given the offer, when the dad answers it, then home no longer offers it")
    func answeredOfferIsGone() async throws {
        let anna = oneYearOld(for: 5)
        try await family([anna])
        try await progress.add(quest(with: anna, daysAgo: 100))
        let offer = try #require(try await sut.execute(childID: nil, worldID: nil, on: today)?.sagaOffer)

        await DefaultAnswerSagaOfferUseCase(repository: offers).execute(occasionID: offer.id)

        let overview = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(overview.sagaOffer == nil)
    }

    @Test("Given a birthday with nothing done in that year, or one 31 days ago, when reading home, then no film is offered")
    func noOfferForAnEmptyOrOldOccasion() async throws {
        let anna = oneYearOld(for: 5)
        try await family([anna])
        let empty = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(empty.sagaOffer == nil)

        // Done after the birthday: it belongs to the second year.
        try await progress.add(quest(with: anna, daysAgo: 2))
        let later = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(later.sagaOffer == nil)

        let older = oneYearOld(for: 31, name: "Νίκος")
        try await family([older])
        try await progress.add(quest(with: older, daysAgo: 100))
        let late = try #require(try await sut.execute(childID: nil, worldID: nil, on: today))
        #expect(late.sagaOffer == nil)
    }
}
