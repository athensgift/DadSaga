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
    private let recorder: ProgressRecorder

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        photoStore: any PhotoStore
    ) {
        recorder = ProgressRecorder(
            contentRepository: contentRepository, progressRepository: progressRepository, photoStore: photoStore
        )
    }

    public func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange {
        guard request.date <= now else { throw MomentError.dateInFuture }
        let change = try await recorder.record(
            .first(id: request.firstID),
            childID: request.childID,
            date: request.date,
            journal: JournalInput(note: request.note, photo: request.photo),
            unknown: MomentError.unknownFirst(request.firstID)
        )
        guard change.eventID != nil else { throw MomentError.alreadyCaptured(request.firstID) }
        return change
    }
}
