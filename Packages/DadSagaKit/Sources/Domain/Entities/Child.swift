import Foundation

public struct Child: Hashable, Sendable {
    public var name: String
    public var birthDate: Date

    public init(name: String, birthDate: Date) {
        self.name = name
        self.birthDate = birthDate
    }

    /// Completed months of age at `date`. Never negative.
    public func ageInMonths(at date: Date, calendar: Calendar = .current) -> Int {
        let months = calendar.dateComponents([.month], from: birthDate, to: date).month ?? 0
        return max(0, months)
    }
}
