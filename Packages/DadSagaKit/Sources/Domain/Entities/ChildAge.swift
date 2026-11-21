/// A child's age on a day (ADR-0053 §1): before the birth, or the completed Gregorian months since the birth day
/// (ADR-0048 §2). The one age every world, card, period and film is decided by.
public enum ChildAge: Hashable, Sendable {
    /// Not born yet, or a day before the birth day.
    case beforeBirth
    /// Completed months since the birth day; 0 on the birth day itself.
    case months(Int)

    /// The completed months, or `nil` before the birth.
    public var months: Int? {
        if case .months(let months) = self { months } else { nil }
    }
}
