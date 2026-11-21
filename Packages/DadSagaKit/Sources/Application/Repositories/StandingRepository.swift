import Domain

/// What the store keeps so the dad's title never goes down and gear he had stays (ADR-0055 §3). Each field only grows.
public protocol StandingRepository: Sendable {
    /// `KeptStanding.fresh` while there is no family: nothing to keep.
    func fetchKept() async throws -> KeptStanding
    /// Keeps the title held and the gear from before titles. Writes nothing while there is no family.
    func keep(titleID: String?, gearIDs: [String]) async throws
    /// The title whose card the dad closed. Writes nothing while there is no family.
    func markSeen(titleID: String) async throws
}
