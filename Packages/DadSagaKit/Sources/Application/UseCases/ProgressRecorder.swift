import Domain
import Foundation

/// What recording something did to the dad's progress.
public struct ProgressChange: Hashable, Sendable {
    public let before: DadProgress
    public let after: DadProgress
    /// The event that was recorded, so the dad can undo it. `nil` when nothing was recorded.
    public let eventID: UUID?

    public init(before: DadProgress, after: DadProgress, eventID: UUID?) {
        self.before = before
        self.after = after
        self.eventID = eventID
    }
}

public enum ProgressError: Error, Equatable {
    case unknownQuest(String)
    case unknownBoss(String)
    case unknownEvent
    /// More than `ProgressEvent.photoLimit` photos on one entry.
    case tooManyPhotos
    /// An edit kept a photo the entry doesn't have.
    case unknownPhoto
}

/// The one way a quest, a boss or a first is recorded: check the content exists, store the event with the dad's note
/// and photos, and say what it changed. A boss or a first counts once per child; when the child already has it, nothing
/// is stored and the change has no `eventID`. The gear from before titles is kept first; the title never is, so an
/// Undo can take it back (ADR-0055 §3, §4).
struct ProgressRecorder {
    let contentRepository: any ContentRepository
    let progressRepository: any ProgressRepository
    let standingRepository: any StandingRepository
    let photoStore: any PhotoStore

    /// - Parameter unknown: thrown when the catalog has no such content.
    func record(
        _ kind: ProgressEvent.Kind,
        childID: UUID,
        date: Date,
        journal: JournalInput,
        unknown: some Error
    ) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        // Stored under the content's current id, even when asked by a former one (e.g. an old widget link).
        guard let kind = catalog.canonical(kind) else { throw unknown }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        let unchanged = ProgressChange(before: before, after: before, eventID: nil)
        // The usual repeat stops here, before any photo is written; `record` still catches two saves at once.
        guard !before.isAlreadyCounted(kind, for: childID) else { return unchanged }
        try await StandingKeeper(standingRepository: standingRepository).keepBeforeRecording(before, catalog: catalog)
        let recorder = EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
        guard let event = try await recorder.record(kind, childID: childID, date: date, journal: journal) else {
            return unchanged
        }
        return ProgressChange(before: before, after: DadProgress(events: events + [event], catalog: catalog), eventID: event.id)
    }
}
