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
    public var birthDate: Date
    public var gender: Gender
    public var skinTone: SkinTone

    public init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        gender: Gender = .boy,
        skinTone: SkinTone = .mediumLight
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.skinTone = skinTone
    }

    /// Completed months of age at `date`. Never negative.
    public func ageInMonths(at date: Date, calendar: Calendar = .current) -> Int {
        let months = calendar.dateComponents([.month], from: birthDate, to: date).month ?? 0
        return max(0, months)
    }
}
