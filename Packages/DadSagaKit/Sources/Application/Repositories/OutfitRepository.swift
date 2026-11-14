import Domain

/// Port for the dad's wardrobe choices.
public protocol OutfitRepository: Sendable {
    func fetchOutfit() async throws -> Outfit
    func save(_ outfit: Outfit) async throws
    /// Only the developer reset uses this.
    func deleteAll() async throws
}
