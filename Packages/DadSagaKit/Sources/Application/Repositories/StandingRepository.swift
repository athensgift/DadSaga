import Domain

/// What the store keeps so a deletion never lowers the dad's title and gear he had stays (ADR-0055 §3). The title and
/// the gear only grow. The closed card goes back only when an Undo takes back the title it was for.
public protocol StandingRepository: Sendable {
    /// `KeptStanding.fresh` while there is no family: nothing to keep.
    func fetchKept() async throws -> KeptStanding
    /// Keeps the title held and the gear from before titles. Writes nothing while there is no family.
    func keep(titleID: String?, gearIDs: [String]) async throws
    /// The title whose card counts as closed: the one the dad closed, or, after an Undo took that title back, the one
    /// he still holds. Writes nothing while there is no family.
    func markSeen(titleID: String) async throws
}
