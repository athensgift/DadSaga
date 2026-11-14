import Domain

/// The dad's wardrobe choices.
public protocol GetOutfitUseCase: Sendable {
    func execute() async throws -> Outfit
}

public struct DefaultGetOutfitUseCase: GetOutfitUseCase {
    private let repository: any OutfitRepository

    public init(repository: any OutfitRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Outfit {
        try await repository.fetchOutfit()
    }
}

/// Changes what the hero wears in one slot.
public protocol SetOutfitChoiceUseCase: Sendable {
    func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit
}

public struct DefaultSetOutfitChoiceUseCase: SetOutfitChoiceUseCase {
    private let repository: any OutfitRepository

    public init(repository: any OutfitRepository) {
        self.repository = repository
    }

    public func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit {
        var outfit = try await repository.fetchOutfit()
        outfit.choices[skill] = choice == .automatic ? nil : choice
        try await repository.save(outfit)
        return outfit
    }
}
