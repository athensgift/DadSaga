import Domain

/// What the store keeps so the dad's title never goes down and gear he had stays (ADR-0055 §3). Each field only grows,
/// except when an Undo puts back what was kept before the entry it takes back.
public protocol StandingRepository: Sendable {
    /// `KeptStanding.fresh` while there is no family: nothing to keep.
    func fetchKept() async throws -> KeptStanding
    /// Keeps the title held and the gear from before titles. Writes nothing while there is no family.
    func keep(titleID: String?, gearIDs: [String]) async throws
    /// The title whose card the dad closed. Writes nothing while there is no family.
    func markSeen(titleID: String) async throws
    /// Puts back everything kept, the closed card's title included, as it was just before an entry an Undo takes back.
    /// Writes nothing while there is no family.
    func restore(_ kept: KeptStanding) async throws
}
