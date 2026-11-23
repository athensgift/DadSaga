import Domain
import Foundation

/// A note and photos the dad may leave when he completes something. All optional; never asked for.
public struct JournalInput: Equatable, Sendable {
    public let note: String?
    /// In the dad's order; the first is the cover. At most `ProgressEvent.photoLimit`.
    public let photos: [Data]

    public static let empty = JournalInput()

    public init(note: String? = nil, photos: [Data] = []) {
        self.note = note
        self.photos = photos
    }
}

/// Stores new photos first, then the event; if a photo or the event can't be stored, every photo stored for it is
/// removed again so nothing is orphaned. A removed photo is deleted only once the event no longer points to it
/// (ADR-0042 §1).
struct EventRecorder {
    let progressRepository: any ProgressRepository
    let photoStore: any PhotoStore

    /// Stores the event by `authorID` with the journal. A boss this author already beat with the child, or a first
    /// anyone already captured with them, is not stored again: then the result is `nil` and no photo is kept.
    func record(
        _ kind: ProgressEvent.Kind,
        authorID: UUID,
        childID: UUID,
        date: Date,
        journal: JournalInput
    ) async throws -> ProgressEvent? {
        guard journal.photos.count <= ProgressEvent.photoLimit else { throw ProgressError.tooManyPhotos }
        let photoIDs = try await save(journal.photos)
        let event = ProgressEvent(
            authorID: authorID, kind: kind, childID: childID, date: date, note: journal.note.trimmedOrNil,
            photoIDs: photoIDs
        )
        let added: Bool
        do {
            if kind.countsOncePerChild {
                added = try await progressRepository.addUnlessRecorded(event)
            } else {
                try await progressRepository.add(event)
                added = true
            }
        } catch {
            await delete(photoIDs)
            throw error
        }
        guard added else {
            await delete(photoIDs)
            return nil
        }
        return event
    }

    /// Saves `event` with a new date, note and photos. Its id, its author, what it was and the child stay the same.
    /// - Parameter photos: every photo it keeps, in order. More than `ProgressEvent.photoLimit`, or a kept id the event
    ///   doesn't have, throws before anything is written.
    func update(_ event: ProgressEvent, date: Date, note: String?, photos: [EntryPhoto]) async throws {
        guard photos.count <= ProgressEvent.photoLimit else { throw ProgressError.tooManyPhotos }
        let keptIDs = photos.compactMap { if case .kept(let id) = $0 { id } else { nil } }
        guard Set(keptIDs).count == keptIDs.count, Set(keptIDs).isSubset(of: event.photoIDs) else {
            throw ProgressError.unknownPhoto
        }
        var addedIDs: [String] = []
        var photoIDs: [String] = []
        do {
            for photo in photos {
                switch photo {
                case .kept(let id):
                    photoIDs.append(id)
                case .added(let data):
                    let id = try await photoStore.save(data)
                    addedIDs.append(id)
                    photoIDs.append(id)
                }
            }
            try await progressRepository.update(ProgressEvent(
                id: event.id, authorID: event.authorID, kind: event.kind, childID: event.childID, date: date,
                note: note.trimmedOrNil, photoIDs: photoIDs
            ))
        } catch {
            await delete(addedIDs)
            throw error
        }
        await delete(event.photoIDs.filter { !photoIDs.contains($0) })
    }

    /// Stores the photos in order. If one can't be stored, the ones already stored are removed again.
    private func save(_ photos: [Data]) async throws -> [String] {
        var ids: [String] = []
        do {
            for photo in photos {
                ids.append(try await photoStore.save(photo))
            }
        } catch {
            await delete(ids)
            throw error
        }
        return ids
    }

    private func delete(_ ids: [String]) async {
        for id in ids {
            await photoStore.delete(id: id)
        }
    }
}

/// Adds, changes or removes the note and photos on any of the player's own entries (quest, boss or moment). The date and
/// what it was stay. Another parent's entry throws `ProgressError.notYourEntry` (ADR-0065 §3.4).
public protocol UpdateJournalUseCase: Sendable {
    /// - Parameter photos: every photo the entry keeps, in order (see `EntryPhoto`).
    func execute(eventID: UUID, note: String?, photos: [EntryPhoto]) async throws
}

public struct DefaultUpdateJournalUseCase: UpdateJournalUseCase {
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore

    public init(
        profileRepository: any ProfileRepository, progressRepository: any ProgressRepository, photoStore: any PhotoStore
    ) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(eventID: UUID, note: String?, photos: [EntryPhoto]) async throws {
        // Refused before any photo is written.
        let event = try await OwnEntries(
            profileRepository: profileRepository, progressRepository: progressRepository, photoStore: photoStore
        ).find(eventID).entry
        try await EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
            .update(event, date: event.date, note: note, photos: photos)
    }
}
