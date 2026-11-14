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

/// A child as drawn next to the dad.
public struct CompanionModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let stage: CompanionStage
    public let gender: GenderChoice
    public let skin: SkinToneChoice
}

extension ChildDraft {
    /// The stage the child is drawn at, given today's date.
    func stage(at date: Date, calendar: Calendar = .current) -> CompanionStage {
        CompanionStage(ageInMonths: child.ageInMonths(at: date, calendar: calendar))
    }
}
