import Foundation

/// How old a child looks on screen.
public enum CompanionStage: CaseIterable, Sendable {
    case baby, toddler, preschooler, kid

    /// 0–11 months baby, 1–2 years toddler, 3–5 years preschooler, 6+ kid.
    public init(ageInMonths months: Int) {
        switch months {
        case ..<12: self = .baby
        case ..<36: self = .toddler
        case ..<72: self = .preschooler
        default: self = .kid
        }
    }
}

/// A visible change on a child, earned by capturing a legendary moment.
public enum CompanionTrait: CaseIterable, Hashable, Sendable {
    case smile, tooth, walks, partyHat

    /// From the content's `companionTrait`; traits with no drawing (e.g. "crawl") give `nil`.
    init?(content: String) {
        switch content {
        case "smile", "laugh": self = .smile
        case "tooth": self = .tooth
        case "walk": self = .walks
        case "party-hat": self = .partyHat
        default: return nil
        }
    }
}

/// A child as drawn next to the dad.
public struct CompanionModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let stage: CompanionStage
    public let gender: GenderChoice
    public let skin: SkinToneChoice
    public let traits: Set<CompanionTrait>
}

extension ChildDraft {
    /// The stage the child is drawn at, given today's date.
    func stage(at date: Date, calendar: Calendar = .current) -> CompanionStage {
        CompanionStage(ageInMonths: child.ageInMonths(at: date, calendar: calendar))
    }
}
