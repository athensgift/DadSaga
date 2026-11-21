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
    /// The day the child was born, as the dad picked it: not a moment, so it doesn't move with the time zone.
    public var birthDay: CalendarDay
    public var gender: Gender
    public var skinTone: SkinTone

    public init(
        id: UUID = UUID(),
        name: String,
        birthDay: CalendarDay,
        gender: Gender = .boy,
        skinTone: SkinTone = .mediumLight
    ) {
        self.id = id
        self.name = name
        self.birthDay = birthDay
        self.gender = gender
        self.skinTone = skinTone
    }

    /// Completed Gregorian months of age on `today`: the one age rule for worlds, quests, bosses, periods and films
    /// (ADR-0048 §2). Never negative.
    public func ageInMonths(on today: CalendarDay) -> Int {
        birthDay.months(until: today)
    }

    /// The day the child turns `months` months old.
    public func day(atMonths months: Int) -> CalendarDay {
        birthDay.adding(months: months)
    }
}
