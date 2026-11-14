import Application
import Domain
import Testing

@Suite("Outfit use cases")
struct OutfitUseCaseTests {
    @Test("Given choices, when setting and getting them, then automatic clears a slot and others are stored")
    func setsChoices() async throws {
        let repository = SpyOutfitRepository()
        let set = DefaultSetOutfitChoiceUseCase(repository: repository)

        _ = try await set.execute(skill: .care, choice: .item("cloth"))
        _ = try await set.execute(skill: .play, choice: .hidden)
        let outfit = try await set.execute(skill: .care, choice: .automatic)

        #expect(outfit == Outfit(choices: [.play: .hidden]))
        #expect(try await DefaultGetOutfitUseCase(repository: repository).execute() == outfit)
    }
}

actor SpyOutfitRepository: OutfitRepository {
    private var outfit = Outfit()

    func fetchOutfit() async throws -> Outfit {
        outfit
    }

    func save(_ outfit: Outfit) async throws {
        self.outfit = outfit
    }

    func deleteAll() async throws {
        outfit = Outfit()
    }
}
