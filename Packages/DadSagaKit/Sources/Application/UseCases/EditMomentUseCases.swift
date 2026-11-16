import Domain
import Foundation

/// Corrects a captured moment: when it happened, the note and the photo. The first and the child stay the same.
public protocol UpdateMomentUseCase: Sendable {
    func execute(momentID: UUID, happenedOn date: Date, note: String?, photo: PhotoChange, now: Date) async throws
}

public struct DefaultUpdateMomentUseCase: UpdateMomentUseCase {
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore

    public init(progressRepository: any ProgressRepository, photoStore: any PhotoStore) {
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(momentID: UUID, happenedOn date: Date, note: String?, photo: PhotoChange, now: Date) async throws {
        guard let event = try await progressRepository.fetchEvents().first(where: { $0.id == momentID }),
              case .first = event.kind else { throw MomentError.unknownMoment }
        guard date <= now else { throw MomentError.dateInFuture }

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
                date: date,
                note: note.trimmedOrNil,
                photoID: photoID
            )
        )
        // Only after the moment points elsewhere is the old photo safe to remove.
        if let old = event.photoID, old != photoID {
            await photoStore.delete(id: old)
        }
    }
}

/// A moment's photo, as stored image data.
public protocol GetPhotoUseCase: Sendable {
    func execute(id: String) async -> Data?
}

public struct DefaultGetPhotoUseCase: GetPhotoUseCase {
    private let photoStore: any PhotoStore

    public init(photoStore: any PhotoStore) {
        self.photoStore = photoStore
    }

    public func execute(id: String) async -> Data? {
        await photoStore.load(id: id)
    }
}
