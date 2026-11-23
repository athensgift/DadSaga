import Domain
import Foundation

/// Corrects a captured moment: when it happened, the note and the photos. The first and the child stay the same. Only
/// the player's own: another parent's moment throws `ProgressError.notYourEntry` (ADR-0065 §3.4).
public protocol UpdateMomentUseCase: Sendable {
    /// - Parameter photos: every photo the moment keeps, in order (see `EntryPhoto`).
    func execute(momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date) async throws
}

public struct DefaultUpdateMomentUseCase: UpdateMomentUseCase {
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

    public func execute(
        momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date
    ) async throws {
        let event = try await OwnEntries(
            profileRepository: profileRepository, progressRepository: progressRepository, photoStore: photoStore
        ).find(momentID).entry
        guard case .first = event.kind else { throw MomentError.unknownMoment }
        guard date <= now else { throw MomentError.dateInFuture }
        try await EventRecorder(progressRepository: progressRepository, photoStore: photoStore)
            .update(event, date: date, note: note, photos: photos)
    }
}

/// An entry's photo, decoded only as large as it is shown, so a small row never holds a full photo in memory.
public protocol GetPhotoUseCase: Sendable {
    /// - Parameter maxPixelSize: the longest side, in pixels, the photo is shown at.
    func execute(id: String, maxPixelSize: Int) async -> Data?
}

public struct DefaultGetPhotoUseCase: GetPhotoUseCase {
    private let photoStore: any PhotoStore

    public init(photoStore: any PhotoStore) {
        self.photoStore = photoStore
    }

    public func execute(id: String, maxPixelSize: Int) async -> Data? {
        await photoStore.thumbnail(id: id, maxPixelSize: maxPixelSize)
    }
}
