import Domain
import Foundation

public enum MomentError: Error, Equatable {
    case unknownFirst(String)
    case alreadyCaptured(String)
    case dateInFuture
    case unknownMoment
}

/// What to do with a moment's photo when saving it.
public enum PhotoChange: Equatable, Sendable {
    case keep
    case remove
    case replace(Data)
}

/// Records a legendary moment (a first) for one child. Each first counts once per child and gives its XP then.
/// The date is when it happened, so a dad can catch up on firsts from before he had the app.
public protocol CaptureMomentUseCase: Sendable {
    func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange
}

public struct CaptureMomentRequest: Equatable, Sendable {
    public let firstID: String
    public let childID: UUID
    public let date: Date
    public let note: String?
    public let photo: Data?

    public init(firstID: String, childID: UUID, date: Date, note: String? = nil, photo: Data? = nil) {
        self.firstID = firstID
        self.childID = childID
        self.date = date
        self.note = note
        self.photo = photo
    }
}

public struct DefaultCaptureMomentUseCase: CaptureMomentUseCase {
    private let contentRepository: any ContentRepository
    private let progressRepository: any ProgressRepository
    private let photoStore: any PhotoStore

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore
    ) {
        self.contentRepository = contentRepository
        self.progressRepository = progressRepository
        self.photoStore = photoStore
    }

    public func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange {
        let catalog = try await contentRepository.fetchCatalog()
        guard catalog.firsts.contains(where: { $0.id == request.firstID }) else {
            throw MomentError.unknownFirst(request.firstID)
        }
        guard request.date <= now else { throw MomentError.dateInFuture }
        let events = try await progressRepository.fetchEvents()
        let before = DadProgress(events: events, catalog: catalog)
        guard !before.capturedFirstIDs(for: request.childID).contains(request.firstID) else {
            throw MomentError.alreadyCaptured(request.firstID)
        }
        let event = try await EventRecorder(progressRepository: progressRepository, photoStore: photoStore).record(
            .first(id: request.firstID),
            childID: request.childID,
            date: request.date,
            journal: JournalInput(note: request.note, photo: request.photo)
        )
        return ProgressChange(
            before: before,
            after: DadProgress(events: events + [event], catalog: catalog),
            eventID: event.id
        )
    }
}

extension String? {
    /// Trimmed, or `nil` when nothing is left.
    var trimmedOrNil: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
