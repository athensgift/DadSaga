import Domain
import Foundation

/// Port for the log of things the dad has done. The game itself only ever adds events (ADR-0006);
/// `update` and `delete` exist for the dad correcting his own entries (ADR-0021).
public protocol ProgressRepository: Sendable {
    func fetchEvents() async throws -> [ProgressEvent]
    /// The photo ids of every stored entry, those `fetchEvents` leaves out included (content the app no longer knows),
    /// whatever the child. A photo not in it belongs to no entry (ADR-0048 §6).
    func referencedPhotoIDs() async throws -> Set<String>
    func add(_ event: ProgressEvent) async throws
    /// Adds a boss or a first unless it is already recorded with the child: a boss by the same author, a first by
    /// anyone (ADR-0065 §3.3). Checked and stored in one step, so two saves at the same moment can never both land.
    /// Returns whether it was added.
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool
    /// Sets the stored entry's date, note and photos to `event`'s where they differ; never its author, kind, content or
    /// child, and an equal value is never written (ADR-0065 §1). Throws `ProgressError.unknownEvent` if there is none
    /// (deleted meanwhile), so a caller that wrote photos for it can remove them again.
    func update(_ event: ProgressEvent) async throws
    func delete(id: UUID) async throws
}
