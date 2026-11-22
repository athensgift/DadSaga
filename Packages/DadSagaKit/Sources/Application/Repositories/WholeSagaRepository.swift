import Domain
import Foundation

/// Port for the saga as a whole: read it all, replace it all, or erase it all, each in one write, so either all of it
/// happens or none of it does (ADR-0030 §8, ADR-0057 §7).
public protocol WholeSagaRepository: Sendable {
    /// The profile, the children (those removed from the family apart), every entry the store maps, the wardrobe and
    /// the kept standing, read together. `nil` when there is no profile.
    func readAll() async throws -> StoredSaga?
    /// Every row replaced by `saga` in one save. The kept standing is written as it is, `nil` gear included.
    func replaceAll(with saga: StoredSaga) async throws
    /// Starting over: every row deleted in one save.
    func eraseAll() async throws
}
