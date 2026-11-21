import Foundation

public enum Gender: String, CaseIterable, Hashable, Sendable {
    case boy, girl
}

/// Five skin tones, light to deep, the same scale emoji use. Applies to the dad and to every child.
public enum SkinTone: String, CaseIterable, Hashable, Sendable {
    case light, mediumLight, medium, mediumDark, dark
}

/// One of the dad's companions.
public struct Child: Hashable, Identifiable, Sendable {
    /// Stable across edits, so progress recorded with this child stays linked to them.
    public let id: UUID
    public var name: String
    /// The day the child was born, as the dad picked it: not a moment, so it doesn't move with the time zone. `nil`
    /// while the child is not born yet (ADR-0053 §1): no due date is kept.
    public var birthDay: CalendarDay?
    public var gender: Gender
    public var skinTone: SkinTone

    public init(
        id: UUID = UUID(),
        name: String,
        birthDay: CalendarDay?,
        gender: Gender = .boy,
        skinTone: SkinTone = .mediumLight
    ) {
        self.id = id
        self.name = name
        self.birthDay = birthDay
        self.gender = gender
        self.skinTone = skinTone
    }

    public var isBorn: Bool { birthDay != nil }

    /// The child's age on `day`: the one age rule for worlds, cards, periods and films (ADR-0048 §2, ADR-0053 §1).
    /// Before the birth when there is no birth day or `day` is earlier; otherwise the completed Gregorian months.
    public func age(on day: CalendarDay) -> ChildAge {
        guard let birthDay, birthDay <= day else { return .beforeBirth }
        return .months(birthDay.months(until: day))
    }

    /// The day the child turns `months` months old; `nil` while not born.
    public func day(atMonths months: Int) -> CalendarDay? {
        birthDay?.adding(months: months)
    }
}
