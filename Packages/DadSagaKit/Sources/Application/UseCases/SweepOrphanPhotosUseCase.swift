import Foundation

/// Deletes photo files that no entry points to, left behind when the app stopped between two writes: starting over
/// erases the store before the photos, saving an entry writes its photos before the entry (ADR-0048 §5).
/// It runs once at launch and shows nothing.
public protocol SweepOrphanPhotosUseCase: Sendable {
    /// Returns how many files it deleted.
    @discardableResult
    func execute(now: Date) async throws -> Int
}

/// A photo lost by mistake can never come back, while an orphan only costs space until the next launch. So it deletes
/// nothing when the saga can't be read or isn't there, and never a file younger than `minimumAge` or without a date.
public struct DefaultSweepOrphanPhotosUseCase: SweepOrphanPhotosUseCase {
    /// Covers a save still under way, which may wait for the store to open and migrate, and a clock set by hand.
    public static let defaultMinimumAge: TimeInterval = 24 * 60 * 60

    private let profileRepository: any ProfileRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore
    private let minimumAge: TimeInterval

    public init(
        profileRepository: any ProfileRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore,
        minimumAge: TimeInterval = defaultMinimumAge
    ) {
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
        self.minimumAge = minimumAge
    }

    /// The files are listed before the entries are read, so a photo saved with its entry in between is never seen
    /// without its entry. Any read that fails throws before anything is deleted.
    @concurrent
    public func execute(now: Date) async throws -> Int {
        let photos = try await photoStore.storedPhotos()
        guard !photos.isEmpty, try await profileRepository.fetchProfile() != nil else { return 0 }
        let referenced = try await progressRepository.referencedPhotoIDs()
        let cutoff = now.addingTimeInterval(-minimumAge)
        let orphans = photos.filter { photo in
            guard let savedAt = photo.savedAt, savedAt <= cutoff else { return false }
            return !referenced.contains(photo.id)
        }
        for orphan in orphans {
            await photoStore.delete(id: orphan.id)
        }
        return orphans.count
    }
}
