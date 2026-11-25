import Domain
import Foundation
import Synchronization

/// Imports a copy of the saga in place of the one on the phone (ADR-0057 §7): the whole copy is read and checked
/// first, then the dad is asked, then it replaces the saga in one save. Until that save, the saga is untouched.
public protocol RestoreSagaUseCase: Sendable {
    /// Reads and checks the whole file, storing its photos under new ids. Throws `SagaCopyError`, or
    /// `CancellationError` when cancelled; either way every photo it stored is deleted again.
    func open(fileAt url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> OpenedSagaCopy
    /// Replaces the saga with `opened`, then deletes the old saga's photos and brings the copy's film answers, the
    /// reminders and the notifications in line. When the replace throws, nothing has changed and `opened` is discarded.
    func restore(_ opened: OpenedSagaCopy, on date: Date) async throws
    /// The dad said no: deletes the photos `open` stored.
    func discard(_ opened: OpenedSagaCopy) async
}

/// A copy read, checked and waiting for the dad's answer.
public struct OpenedSagaCopy: Hashable, Sendable {
    public let copy: SagaCopy
    /// The photos stored for it, deleted again if it is never restored.
    public let adoptedPhotoIDs: [String]

    public init(copy: SagaCopy, adoptedPhotoIDs: [String]) {
        self.copy = copy
        self.adoptedPhotoIDs = adoptedPhotoIDs
    }

    public var madeAt: Date { copy.madeAt }
    /// For the question: whose saga this is.
    public var childNames: [String] { copy.saga.profile.children.map(\.name) }
}

public struct DefaultRestoreSagaUseCase: RestoreSagaUseCase {
    private let wholeSaga: any WholeSagaRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore
    private let sagaOffers: any SagaOfferRepository
    private let files: any SagaCopyFiles
    private let renewReminders: any RenewWeeklyRemindersUseCase

    /// - Parameter renewReminders: so the reminders follow the restored family (ADR-0024).
    public init(
        wholeSaga: any WholeSagaRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore,
        sagaOffers: any SagaOfferRepository,
        files: any SagaCopyFiles,
        renewReminders: any RenewWeeklyRemindersUseCase
    ) {
        self.wholeSaga = wholeSaga
        self.progressRepository = progressRepository
        self.photoStore = photoStore
        self.sagaOffers = sagaOffers
        self.files = files
        self.renewReminders = renewReminders
    }

    /// Photos adopted before a failure are new files no entry points to; a kill before they are deleted leaves them
    /// to the sweep (ADR-0048 §6), which waits a day for files this young.
    @concurrent
    public func open(fileAt url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> OpenedSagaCopy {
        let adopted = Mutex<[String]>([])
        let photoStore = photoStore
        do {
            let copy = try await files.read(
                fileAt: url,
                adopt: { data in
                    let id = try await photoStore.adopt(data)
                    adopted.withLock { $0.append(id) }
                    return id
                },
                progress: progress
            )
            return OpenedSagaCopy(copy: copy, adoptedPhotoIDs: adopted.withLock { $0 })
        } catch {
            await delete(adopted.withLock { $0 })
            if error is CancellationError { throw error }
            throw SagaCopyError(error)
        }
    }

    /// The replace is the commit. An opened copy whose photos are gone (it was discarded) is refused before it.
    /// Everything after it only tidies up: it can't fail, and a kill before it is done
    /// leaves at worst old photos for the sweep and one film offer back.
    @concurrent
    public func restore(_ opened: OpenedSagaCopy, on date: Date) async throws {
        let oldPhotoIDs: Set<String>
        do {
            let stored = Set(try await photoStore.storedPhotos().map(\.id))
            guard stored.isSuperset(of: opened.adoptedPhotoIDs) else { throw SagaCopyError.failed }
            oldPhotoIDs = try await progressRepository.referencedPhotoIDs()
            try await wholeSaga.replaceAll(with: opened.copy.saga)
        } catch {
            await discard(opened)
            throw SagaCopyError(error)
        }
        await delete(Array(oldPhotoIDs.subtracting(opened.adoptedPhotoIDs)))
        await sagaOffers.deleteAll()
        for occasionID in opened.copy.answeredOccasionIDs.sorted() {
            await sagaOffers.markAnswered(occasionID)
        }
        await renewReminders.execute(on: date)
    }

    /// Never a photo the saga points to: after a restore, the adopted photos are the saga's own. When the entries
    /// can't be read, nothing is deleted, and the sweep finds the orphans later (ADR-0048 §6).
    public func discard(_ opened: OpenedSagaCopy) async {
        guard let referenced = try? await progressRepository.referencedPhotoIDs() else { return }
        await delete(opened.adoptedPhotoIDs.filter { !referenced.contains($0) })
    }

    private func delete(_ ids: [String]) async {
        for id in ids {
            await photoStore.delete(id: id)
        }
    }
}
