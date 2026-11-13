import Domain

/// Port for the log of things the dad has done. Events are only ever added (ADR-0006: nothing is lost).
public protocol ProgressRepository: Sendable {
    func fetchEvents() async throws -> [ProgressEvent]
    func add(_ event: ProgressEvent) async throws
    /// Wipes the log. Only the developer reset uses this.
    func deleteAll() async throws
}
