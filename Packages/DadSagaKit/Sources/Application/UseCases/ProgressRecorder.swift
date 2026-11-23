import Domain
import Foundation

/// What recording something did to the dad's progress.
public struct ProgressChange: Hashable, Sendable {
    public let before: DadProgress
    public let after: DadProgress
    /// The event that was recorded, so the dad can undo it. `nil` when nothing was recorded.
    public let eventID: UUID?
    /// The child's moment the event captured, when it was a first.
    public let moment: CapturedMoment?

    public init(before: DadProgress, after: DadProgress, eventID: UUID?, moment: CapturedMoment? = nil) {
        self.before = before
        self.after = after
        self.eventID = eventID
        self.moment = moment
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
    /// Recording before onboarding: there is no player to be the entry's author.
    case noProfile
    /// Changing an entry another parent recorded: each parent edits, undoes and deletes only their own (ADR-0065 §3.4).
    case notYourEntry
}

/// The one way a quest, a boss or a first is recorded: check the content exists, store the event with the dad's note
/// and photos, and say what it changed. A boss counts once per child for each parent, a first once per child for the
/// family (ADR-0065 §3.3): when he already beat the boss with the child, or anyone already captured the first, nothing
/// is stored and the change has no `eventID`. Nothing is kept for the title, so an Undo can take it back (ADR-0055 §3).
/// The entry's author is the stored player (ADR-0065 §5).
struct ProgressRecorder {
    let contentRepository: any ContentRepository
    let progressRepository: any ProgressRepository
    let profileRepository: any ProfileRepository
    let photoStore: any PhotoStore

    /// - Parameter unknown: thrown when the catalog has no such content.
    func record(
        _ kind: ProgressEvent.Kind,
        childID: UUID,
        date: Date,
        journal: JournalInput,
        unknown: some Error
    ) async throws -> ProgressChange {
        guard let player = try await profileRepository.fetchProfile() else { throw ProgressError.noProfile }
        let catalog = try await contentRepository.fetchCatalog()
        // Stored under the content's current id, even when asked by a former one (e.g. an old widget link).
        guard let kind = catalog.canonical(kind) else { throw unknown }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(of: player, events: events, catalog: catalog)
        let unchanged = ProgressChange(before: before, after: before, eventID: nil)
        // The usual repeat stops here, before any photo is written; `record` still catches two saves at once.
        let isRecorded = switch kind {
        case .quest: false
        case .boss(let id): before.defeatedBossIDs(for: childID).contains(id)
        case .first(let id): FamilyMoments(events: events, catalog: catalog).capturedFirstIDs(for: childID).contains(id)
        }
        guard !isRecorded else { return unchanged }
        let recorder = EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
        guard let event = try await recorder.record(
            kind, authorID: player.id, childID: childID, date: date, journal: journal
        ) else {
            return unchanged
        }
        let moment: CapturedMoment? = if case .first = kind {
            FamilyMoments(events: events + [event], catalog: catalog).moments(for: childID).first { $0.eventID == event.id }
        } else {
            nil
        }
        return ProgressChange(
            before: before, after: DadProgress(of: player, events: events + [event], catalog: catalog),
            eventID: event.id, moment: moment
        )
    }
}
