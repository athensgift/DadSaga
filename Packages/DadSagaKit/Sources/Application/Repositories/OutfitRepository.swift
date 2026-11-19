import Domain

/// Port for the dad's wardrobe choices.
public protocol OutfitRepository: Sendable {
    func fetchOutfit() async throws -> Outfit
    /// Changes one slot and returns the whole outfit, in one step, so changes to two slots at once never undo each
    /// other. `.automatic` clears the slot.
    func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit
    /// Only the developer reset uses this.
    func deleteAll() async throws
}
