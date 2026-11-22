import Domain

/// What the store keeps so a deletion never lowers the dad's title (ADR-0055 §3). The title only grows. The closed card
/// goes back only when an Undo takes back the title it was for.
public protocol StandingRepository: Sendable {
    /// `KeptStanding()` while there is no family: nothing kept.
    func fetchKept() async throws -> KeptStanding
    /// Keeps the title held, before a deletion. Writes nothing while there is no family.
    func keep(titleID: String) async throws
    /// The title whose card counts as closed: the one the dad closed, or, after an Undo took that title back, the one
    /// he still holds. Writes nothing while there is no family.
    func markSeen(titleID: String) async throws
}
