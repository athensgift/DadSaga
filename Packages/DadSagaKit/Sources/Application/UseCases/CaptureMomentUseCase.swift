import Domain
import Foundation

public enum MomentError: Error, Equatable {
    case unknownFirst(String)
    case alreadyCaptured(String)
    case dateInFuture
    /// A first of after the birth, dated before the child's birth day (ADR-0053 §3).
    case dateBeforeBirth
    /// A first that isn't offered to this child today: a retired one, or one of after the birth for a child not born yet.
    case notOffered(String)
    /// A child who isn't in the family: there is no birth day to date the first from.
    case unknownChild
    case unknownMoment
}

/// Records a legendary moment (a first) for one child. Each first counts once per child and gives its XP then.
/// The date is when it happened, so a dad can catch up on firsts from before he had the app: any day up to today
/// for a first before birth, from the birth day for every other. Only a first offered to the child today is captured
/// (`UnlockRules.firsts`, ADR-0053 §3). Its photos and note come after, through `UpdateMomentUseCase` (ADR-0042 §5).
public protocol CaptureMomentUseCase: Sendable {
    func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange
}

public struct CaptureMomentRequest: Equatable, Sendable {
    public let firstID: String
    public let childID: UUID
    public let date: Date

    public init(firstID: String, childID: UUID, date: Date) {
        self.firstID = firstID
        self.childID = childID
        self.date = date
    }
}

public struct DefaultCaptureMomentUseCase: CaptureMomentUseCase {
    private let recorder: ProgressRecorder
    private let timeZone: TimeZone

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        profileRepository: any ProfileRepository,
        photoStore: any PhotoStore,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.timeZone = timeZone
        recorder = ProgressRecorder(
            contentRepository: contentRepository,
            progressRepository: progressRepository,
            profileRepository: profileRepository,
            photoStore: photoStore
        )
    }

    public func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange {
        guard request.date <= now else { throw MomentError.dateInFuture }
        let change = try await recorder.record(
            .first(id: request.firstID),
            childID: request.childID,
            date: request.date,
            journal: .empty,
            unknown: MomentError.unknownFirst(request.firstID)
        ) { player, catalog, kind in
            guard case .first(let id) = kind, let first = catalog.first(id: id) else { return }
            guard let child = player.children.first(where: { $0.id == request.childID }) else {
                throw MomentError.unknownChild
            }
            let today = CalendarDay(now, in: timeZone)
            guard UnlockRules.firsts(in: catalog, age: child.age(on: today)).contains(where: { $0.id == first.id }) else {
                throw MomentError.notOffered(first.id)
            }
            guard UnlockRules.canDate(first, on: CalendarDay(request.date, in: timeZone), child: child, today: today) else {
                throw MomentError.dateBeforeBirth
            }
        }
        guard change.eventID != nil else { throw MomentError.alreadyCaptured(request.firstID) }
        return change
    }
}
