import Domain
import Foundation

/// Exports the saga to one file the dad saves or sends (ADR-0057 §6). Only the dad's own tap runs it: nothing ever asks
/// for a copy (ADR-0006).
public protocol MakeSagaCopyUseCase: Sendable {
    /// Writes the copy and returns where it is. Throws `SagaCopyError`, or `CancellationError` when cancelled; either
    /// way no file is left.
    func execute(on date: Date, progress: @escaping @Sendable (Double) -> Void) async throws -> MadeSagaCopy
    /// Deletes the copies made so far, once they have been saved or sent, and what a stopped copy left.
    func discardCopies() async
}

public struct DefaultMakeSagaCopyUseCase: MakeSagaCopyUseCase {
    private let wholeSaga: any WholeSagaRepository
    private let sagaOffers: any SagaOfferRepository
    private let photoStore: any PhotoStore
    private let files: any SagaCopyFiles

    public init(
        wholeSaga: any WholeSagaRepository,
        sagaOffers: any SagaOfferRepository,
        photoStore: any PhotoStore,
        files: any SagaCopyFiles
    ) {
        self.wholeSaga = wholeSaga
        self.sagaOffers = sagaOffers
        self.photoStore = photoStore
        self.files = files
    }

    /// A photo whose file is gone travels without it, as the timeline already shows the entry without it.
    @concurrent
    public func execute(on date: Date, progress: @escaping @Sendable (Double) -> Void) async throws -> MadeSagaCopy {
        do {
            guard let saga = try await wholeSaga.readAll() else { throw SagaCopyError.nothingToCopy }
            let stored = Set(try await photoStore.storedPhotos().map(\.id))
            let kept = Dictionary(uniqueKeysWithValues: Set(saga.photoIDs).intersection(stored).map { ($0, $0) })
            let copy = SagaCopy(
                saga: saga.replacingPhotoIDs(kept),
                answeredOccasionIDs: await sagaOffers.answeredOccasionIDs(),
                madeAt: date
            )
            let photoStore = photoStore
            return try await files.write(copy, photo: { try await photoStore.storedData(id: $0) }, progress: progress)
        } catch let error as CancellationError {
            throw error
        } catch {
            throw SagaCopyError(error)
        }
    }

    public func discardCopies() async {
        await files.discardTemporaryFiles()
    }
}
