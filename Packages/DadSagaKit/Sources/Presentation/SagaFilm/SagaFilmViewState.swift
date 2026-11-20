import Foundation

/// Display-ready state for the film sheet (ADR-0037 §4). Plain values only.
public enum SagaFilmViewState: Equatable, Sendable {
    case loading
    /// The film can't be read or has no music; the action loads again.
    case unavailable(SagaFilmNotice)
    /// The dad is choosing.
    case ready(SagaFilmSetup)
    case making(SagaFilmMaking)
    case made(SagaFilmMade)
}

public struct SagaFilmNotice: Equatable, Sendable {
    public let message: String
    public let actionTitle: String
}

public struct SagaFilmChildChoice: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
}

public struct SagaFilmPeriodChoice: Equatable, Identifiable, Sendable {
    /// e.g. "year-2", "world-w2-plains", "everything".
    public let id: String
    public let title: String
}

public struct SagaFilmFormatChoice: Equatable, Identifiable, Sendable {
    public let id: SagaFilmFormat
    public let title: String
    public let symbol: String
}

public struct SagaFilmSetup: Equatable, Sendable {
    public let childLabel: String
    public let periodLabel: String
    public let formatLabel: String
    /// Where the film is made and that it isn't kept.
    public let note: String
    /// One per child, when there are several. Empty for one child.
    public let children: [SagaFilmChildChoice]
    public let selectedChildID: UUID
    public let periods: [SagaFilmPeriodChoice]
    public let selectedPeriodID: String
    public let formats: [SagaFilmFormatChoice]
    public let selectedFormat: SagaFilmFormat
    /// Why the last film wasn't finished: the dad left the app, or it failed. `nil` after a cancel.
    public let notice: String?
    /// "Make the film", or "Make it again" under a notice. `nil` when the period has nothing in it.
    public let makeTitle: String?
    /// Shown instead of the make button. Never says what the dad didn't do (ADR-0006).
    public let emptyMessage: String?
}

public struct SagaFilmMaking: Equatable, Sendable {
    public let title: String
    /// From 0 to 1; it never goes back.
    public let progress: Double
    /// e.g. "60%".
    public let progressText: String
    public let note: String
    public let cancelTitle: String
}

public struct SagaFilmMade: Equatable, Sendable {
    /// The film's temporary file, to play and to share.
    public let url: URL
    /// The film's name as the share sheet shows it, e.g. "Άννα – DadSaga".
    public let title: String
    public let format: SagaFilmFormat
    public let shareTitle: String
    public let note: String
    public let anotherTitle: String
}
