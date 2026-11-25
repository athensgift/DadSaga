import Domain
import Foundation

/// Corrects a captured moment: when it happened, the note and the photos. The first and the child stay the same. The
/// day follows the first's rule (`UnlockRules.canDate`, ADR-0053 §3): never before its earliest day, except that a
/// moment already dated earlier keeps its day or moves later. Only the player's own: another parent's moment throws
/// `ProgressError.notYourEntry` (ADR-0065 §3.4).
public protocol UpdateMomentUseCase: Sendable {
    /// - Parameter photos: every photo the moment keeps, in order (see `EntryPhoto`).
    func execute(momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date) async throws
}

public struct DefaultUpdateMomentUseCase: UpdateMomentUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore
    private let timeZone: TimeZone

    public init(
        contentRepository: any ContentRepository,
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.contentRepository = contentRepository
        self.timeZone = timeZone
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(
        momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date
    ) async throws {
        let found = try await OwnEntries(
            profileRepository: profileRepository, progressRepository: progressRepository, photoStore: photoStore
        ).find(momentID)
        let event = found.entry
        guard case .first(let firstID) = event.kind else { throw MomentError.unknownMoment }
        guard date <= now else { throw MomentError.dateInFuture }
        // A first the content no longer has, or a child no longer in the family, has no rule to ask.
        if let first = try await contentRepository.fetchCatalog().first(id: firstID),
           let child = found.player.children.first(where: { $0.id == event.childID }) {
            let allowed = UnlockRules.canDate(
                first, on: CalendarDay(date, in: timeZone), child: child, today: CalendarDay(now, in: timeZone),
                current: CalendarDay(event.date, in: timeZone)
            )
            guard allowed else { throw MomentError.dateBeforeBirth }
        }
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
