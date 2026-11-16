import Domain
import Foundation

/// A note and a photo the dad may leave when he completes something. Both optional; never asked for.
public struct JournalInput: Equatable, Sendable {
    public let note: String?
    public let photo: Data?

    public static let empty = JournalInput()

    public init(note: String? = nil, photo: Data? = nil) {
        self.note = note
        self.photo = photo
    }
}

/// Stores the photo, then the event; if the event can't be stored, the photo is removed again so nothing is orphaned.
struct EventRecorder {
    let progressRepository: any ProgressRepository
    let photoStore: any PhotoStore

    func record(_ kind: ProgressEvent.Kind, childID: UUID, date: Date, journal: JournalInput) async throws -> ProgressEvent {
        var photoID: String?
        if let photo = journal.photo {
            photoID = try await photoStore.save(photo)
        }
        let event = ProgressEvent(kind: kind, childID: childID, date: date, note: journal.note.trimmedOrNil, photoID: photoID)
        do {
            try await progressRepository.add(event)
        } catch {
            if let photoID { await photoStore.delete(id: photoID) }
            throw error
        }
        return event
    }
}

/// Adds, changes or removes the note and photo on any entry (quest, boss or moment). The date and what it was stay.
public protocol UpdateJournalUseCase: Sendable {
    func execute(eventID: UUID, note: String?, photo: PhotoChange) async throws
}

public struct DefaultUpdateJournalUseCase: UpdateJournalUseCase {
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore

    public init(progressRepository: any ProgressRepository, photoStore: any PhotoStore) {
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(eventID: UUID, note: String?, photo: PhotoChange) async throws {
        guard let event = try await progressRepository.fetchEvents().first(where: { $0.id == eventID }) else {
            throw ProgressError.unknownEvent
        }
        var photoID = event.photoID
        switch photo {
        case .keep: break
        case .remove: photoID = nil
        case .replace(let data): photoID = try await photoStore.save(data)
        }
        try await progressRepository.update(
            ProgressEvent(
                id: event.id,
                kind: event.kind,
                childID: event.childID,
                date: event.date,
                note: note.trimmedOrNil,
                photoID: photoID
            )
        )
        // Only after the entry points elsewhere is the old photo safe to remove.
        if let old = event.photoID, old != photoID {
            await photoStore.delete(id: old)
        }
    }
}
