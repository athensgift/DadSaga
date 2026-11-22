import Domain

/// The dad closed the card for a new title: it stays closed, across launches, until a higher title (ADR-0055 §6).
public protocol MarkTitleSeenUseCase: Sendable {
    func execute(titleID: String) async throws
}

public struct DefaultMarkTitleSeenUseCase: MarkTitleSeenUseCase {
    private let standingRepository: any StandingRepository

    public init(standingRepository: any StandingRepository) {
        self.standingRepository = standingRepository
    }

    public func execute(titleID: String) async throws {
        try await standingRepository.markSeen(titleID: titleID)
    }
}
