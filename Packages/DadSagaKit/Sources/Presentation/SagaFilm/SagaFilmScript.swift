import Domain
import Foundation

/// The shape of a saga film: vertical for phones and stories, wide for a television or a computer.
public enum SagaFilmFormat: String, CaseIterable, Hashable, Sendable {
    case vertical, wide

    /// Width over height.
    public var aspectRatio: Double {
        switch self {
        case .vertical: 9.0 / 16
        case .wide: 16.0 / 9
        }
    }
}

/// Which film the sheet opens with. Views pass it along and never look inside.
public struct SagaFilmRequest: Hashable, Sendable {
    let childID: UUID?
    let period: SagaPeriod?

    /// The film of a child, or of the first child, for the period the day suggests.
    public init(childID: UUID? = nil) {
        self.init(childID: childID, period: nil)
    }

    /// The film home offers: a child and the period of the occasion.
    init(childID: UUID?, period: SagaPeriod?) {
        self.childID = childID
        self.period = period
    }
}

/// Everything the renderer needs to draw a film, as display values (ADR-0036 §5): scenes oldest first, each with its
/// length and its card.
public struct SagaFilmScript: Equatable, Sendable {
    public let format: SagaFilmFormat
    /// Photos stay still; scenes still fade (ADR-0037 §3).
    public let reduceMotion: Bool
    public let scenes: [SagaFilmScene]
    public let music: URL
    /// The film's file name without its extension, e.g. "Άννα – DadSaga". Safe as one path component.
    public let title: String
}

public struct SagaFilmScene: Equatable, Sendable {
    public let seconds: Double
    public let card: SagaFilmCard
}

/// What one scene shows. No ages and no XP on any of them (ADR-0037 §2, ADR-0006). Dates, already written, only on
/// the opening, a first and a boss, and only while the film's dates switch is on (ADR-0041); `nil` otherwise.
public enum SagaFilmCard: Equatable, Sendable {
    case opening(name: String, period: String, dates: String?, family: SagaFilmFamily)
    case chapter(heading: String, title: String, tagline: String)
    /// A first: its words, over its cover if it has photos.
    case first(emoji: String, title: String, date: String?, note: String?, photoID: String?)
    /// A boss: its badge and title, over its cover if it has photos.
    case boss(badge: String, title: String, date: String?, photoID: String?)
    /// A photo on its own, without words: a quest's cover, or one of an entry's further photos (ADR-0042 §6).
    case photo(photoID: String)
    case credits(SagaFilmCredits)

    /// The photo the card is drawn over, if any.
    var photoID: String? {
        switch self {
        case .first(_, _, _, _, let photoID), .boss(_, _, _, let photoID): photoID
        case .photo(let photoID): photoID
        case .opening, .chapter, .credits: nil
        }
    }
}

/// The hero and the child as they were at the end of the film's period, drawn as on home.
public struct SagaFilmFamily: Equatable, Sendable {
    public let hero: HeroLook
    public let heroSkin: SkinToneChoice
    public let heroGear: [HeroGearLook]
    public let medals: Int
    public let child: CompanionModel
}

public struct SagaFilmCredits: Equatable, Sendable {
    public let lines: [SagaFilmCreditLine]
    /// "Made with DadSaga".
    public let signature: String
}

public struct SagaFilmCreditLine: Equatable, Sendable {
    /// e.g. "Starring".
    public let role: String
    public let name: String
}
