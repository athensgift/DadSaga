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
            GearItem(id: "cloth", skill: .care, minXP: 20, look: "burpCloth", title: text),
            GearItem(id: "golden", skill: .care, minXP: 500, look: "burpClothGold", title: text)
        ]
    )
    let repository = SpyOutfitRepository()
    let progress = SpyProgressRepository()

    var getWardrobe: DefaultGetWardrobeUseCase {
        DefaultGetWardrobeUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: SpyProfileRepository(),
            progressRepository: progress,
            outfitRepository: repository
        )
    }

    var set: DefaultSetOutfitChoiceUseCase {
        DefaultSetOutfitChoiceUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            progressRepository: progress,
            outfitRepository: repository
        )
    }

    func earnCloth() async throws {
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: .now))
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

    @Test("Given the dad's hero class, when reading the wardrobe, then it carries that class; a removed class gives none")
    func wardrobeHero() async throws {
        let chef = HeroClass(id: "h-x", order: 1, title: Self.text, tagline: Self.text, look: "chef")
        let catalog = ContentCatalog(worlds: [], quests: [], bosses: [], firsts: [], heroClasses: [chef], gear: [])
        let profiles = SpyProfileRepository()
        let sut = DefaultGetWardrobeUseCase(
            contentRepository: StubContentRepository(result: .success(catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            outfitRepository: repository
        )
        let child = Child(name: "Νίκος", birthDate: .now)

        try await profiles.save(PlayerProfile(children: [child], heroClassID: "h-x"))
        #expect(try await sut.execute().hero?.look == "chef")

        try await profiles.save(PlayerProfile(children: [child], heroClassID: "h-gone"))
        #expect(try await sut.execute().hero == nil)
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

    func deleteAll() async throws {
        outfit = Outfit()
    }
}
