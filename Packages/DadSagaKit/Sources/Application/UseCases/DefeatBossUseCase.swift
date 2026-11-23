import Domain
import Foundation

/// Records that the dad got through a boss fight in real life with one of his children. Each boss gives its badge and
/// XP once per child; confirming an already defeated boss changes nothing.
public protocol DefeatBossUseCase: Sendable {
    func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange
}

public struct DefaultDefeatBossUseCase: DefeatBossUseCase {
    private let recorder: ProgressRecorder

    public init(
        contentRepository: any ContentRepository,
        progressRepository: any ProgressRepository,
        profileRepository: any ProfileRepository,
        photoStore: any PhotoStore
    ) {
        recorder = ProgressRecorder(
            contentRepository: contentRepository,
            progressRepository: progressRepository,
            profileRepository: profileRepository,
            photoStore: photoStore
        )
    }

    public func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        try await recorder.record(
            .boss(id: bossID), childID: childID, date: date, journal: journal, unknown: ProgressError.unknownBoss(bossID)
        )
    }
}
