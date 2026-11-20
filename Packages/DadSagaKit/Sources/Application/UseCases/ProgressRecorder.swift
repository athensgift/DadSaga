import Domain
import Foundation

/// What recording something did to the dad's progress.
public struct ProgressChange: Hashable, Sendable {
    public let before: DadProgress
    public let after: DadProgress
    /// The event that was recorded, so the dad can undo it. `nil` when nothing was recorded.
    public let eventID: UUID?
    /// Gear the change earned, to celebrate.
    public let newGear: [GearItem]

    public var gainedXP: Int { after.totalXP - before.totalXP }
    public var leveledUp: Bool { after.level.level > before.level.level }

    /// `gear` is every item in the catalog; the change keeps the ones it newly earned.
    public init(before: DadProgress, after: DadProgress, eventID: UUID?, gear: [GearItem]) {
        self.before = before
        self.after = after
        self.eventID = eventID
        newGear = GearRules.newlyEarned(gear, before: before.skillXP, after: after.skillXP)
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
/// is stored and the change has no `eventID`.
struct ProgressRecorder {
    let contentRepository: any ContentRepository
    let progressRepository: any ProgressRepository
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
        guard catalog.contains(kind) else { throw unknown }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        let unchanged = ProgressChange(before: before, after: before, eventID: nil, gear: catalog.gear)
        // The usual repeat stops here, before any photo is written; `record` still catches two saves at once.
        guard !before.isAlreadyCounted(kind, for: childID) else { return unchanged }
        let recorder = EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
        guard let event = try await recorder.record(kind, childID: childID, date: date, journal: journal) else {
            return unchanged
        }
        return ProgressChange(
            before: before,
            after: DadProgress(events: events + [event], catalog: catalog),
            eventID: event.id,
            gear: catalog.gear
        )
    }
}
