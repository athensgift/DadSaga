import Application
import Domain
import Foundation
import Testing

@Suite("Outfit use cases")
struct OutfitUseCaseTests {
    static let text = Stub.text
    static let catalog = ContentCatalog(
        worlds: [],
        quests: [Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)],
        bosses: [],
        firsts: [],
        gear: [
            GearItem(id: "cloth", skill: .care, look: "burpCloth", title: text),
            GearItem(id: "golden", skill: .care, look: "burpClothGold", title: text)
        ],
        titles: [
            DadTitle(id: "t0", order: 0, minCards: 0, minXP: 0, name: text),
            DadTitle(id: "t1", order: 1, minCards: 1, minXP: 20, gearIDs: ["cloth"], name: text),
            DadTitle(id: "t2", order: 2, minCards: 50, minXP: 5000, gearIDs: ["golden"], name: text)
        ]
    )
    let repository = SpyOutfitRepository()
    let progress = SpyProgressRepository()

    var getWardrobe: DefaultGetWardrobeUseCase {
        DefaultGetWardrobeUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: TheDad(),
            progressRepository: progress,
            outfitRepository: repository,
            standingRepository: InMemoryStanding()
        )
    }

    var set: DefaultSetOutfitChoiceUseCase {
        DefaultSetOutfitChoiceUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)), profileRepository: TheDad(),
            progressRepository: progress,
            outfitRepository: repository,
            standingRepository: InMemoryStanding()
        )
    }

    func earnCloth() async throws {
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: .now))
    }

    @Test("Given an item only the partner's entries reach, when the dad wears it, then it isn't his and nothing changes")
    func partnersGearIsntHis() async throws {
        try await progress.add(ProgressEvent(authorID: .partner, kind: .quest(id: "q1"), childID: UUID(), date: .now))

        await #expect(throws: OutfitError.notEarned("cloth")) {
            _ = try await set.execute(skill: .care, choice: .item("cloth"))
        }

        #expect(try await getWardrobe.execute().earned.isEmpty)
    }

    @Test("Given an earned item, when setting choices and reading the wardrobe, then automatic clears a slot")
    func setsChoices() async throws {
        try await earnCloth()

        _ = try await set.execute(skill: .care, choice: .item("cloth"))
        #expect(try await getWardrobe.execute().equipped.map(\.id) == ["cloth"])
        _ = try await set.execute(skill: .play, choice: .hidden)
        let outfit = try await set.execute(skill: .care, choice: .automatic)

        #expect(outfit == Outfit(choices: [.play: .hidden]))
        #expect(try await getWardrobe.execute().outfit == outfit)
    }

    @Test("Given the dad's hero class, when reading the wardrobe, then it carries that class; a removed class shows as the first")
    func wardrobeHero() async throws {
        let first = HeroClass(id: "h-first", order: 1, title: Self.text, tagline: Self.text, look: "hero")
        let chef = HeroClass(id: "h-x", order: 2, title: Self.text, tagline: Self.text, look: "chef")
        let catalog = ContentCatalog(worlds: [], quests: [], bosses: [], firsts: [], heroClasses: [chef, first], gear: [])
        let profiles = SpyProfileRepository()
        let sut = DefaultGetWardrobeUseCase(
            contentRepository: StubContentRepository(result: .success(catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            outfitRepository: repository,
            standingRepository: InMemoryStanding()
        )
        let child = Child(name: "Νίκος", birthDay: CalendarDay(.now, in: .gmt))

        try await profiles.save(PlayerProfile(children: [child], heroClassID: "h-x"))
        #expect(try await sut.execute().hero?.look == "chef")

        try await profiles.save(PlayerProfile(children: [child], heroClassID: "h-gone"))
        #expect(try await sut.execute().hero?.look == "hero")
    }

    @Test("Given an item not earned, of another slot or unknown, when wearing it, then it throws and nothing changes")
    func onlyEarnedItems() async throws {
        try await earnCloth()

        await #expect(throws: OutfitError.notEarned("golden")) {
            try await set.execute(skill: .care, choice: .item("golden"))
        }
        await #expect(throws: OutfitError.notEarned("cloth")) {
            try await set.execute(skill: .play, choice: .item("cloth"))
        }
        await #expect(throws: OutfitError.notEarned("nope")) {
            try await set.execute(skill: .care, choice: .item("nope"))
        }
        #expect(try await repository.fetchOutfit() == Outfit())
    }
}

actor SpyOutfitRepository: OutfitRepository {
    private var outfit = Outfit()

    func fetchOutfit() async throws -> Outfit {
        outfit
    }

    func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit {
        outfit.choices[skill] = choice == .automatic ? nil : choice
        return outfit
    }
}
