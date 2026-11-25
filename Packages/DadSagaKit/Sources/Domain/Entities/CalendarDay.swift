import Foundation

/// A day on the Gregorian calendar, with no time and no time zone: a birth day is the day the dad picked, wherever the
/// phone is later (ADR-0048 §2).
///
/// Ages and periods are counted on the Gregorian calendar whatever calendar the phone uses, so a child's worlds open at
/// the same age everywhere.
public struct CalendarDay: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// `nil` for a day the Gregorian calendar doesn't have, such as 30 February.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.length(ofMonth: month, in: year)).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    private init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        let parts = Self.gregorian(timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(unchecked: parts.year ?? 1, parts.month ?? 1, parts.day ?? 1)
    }

    /// The first moment of the day in `timeZone`. A day whose midnight a clock change skips starts at the first moment
    /// that exists.
    public func start(in timeZone: TimeZone) -> Date {
        let calendar = Self.gregorian(timeZone)
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        return calendar.startOfDay(for: noon)
    }

    /// The day `months` months later, on the same day of the month or the month's last day if it is shorter: a child
    /// born on 31 January turns one month on 28 or 29 February.
    public func adding(months: Int) -> CalendarDay {
        let index = year * 12 + (month - 1) + months
        let year = Int((Double(index) / 12).rounded(.down))
        let month = index - year * 12 + 1
        return CalendarDay(unchecked: year, month, min(day, Self.length(ofMonth: month, in: year)))
    }

    /// The day `days` days later.
    public func adding(days: Int) -> CalendarDay {
        let utc = Self.gregorian(.gmt)
        let date = utc.date(byAdding: .day, value: days, to: start(in: .gmt)) ?? .distantPast
        return CalendarDay(date, in: .gmt)
    }

    /// Days from this day to `later`: negative when `later` is earlier. Counted on the calendar, so no time zone's
    /// clock change or skipped day is in it.
    public func days(until later: CalendarDay) -> Int {
        Self.gregorian(.gmt).dateComponents([.day], from: start(in: .gmt), to: later.start(in: .gmt)).day ?? 0
    }

    /// Completed months from this day to `later`. Never negative.
    public func months(until later: CalendarDay) -> Int {
        let months = (later.year - year) * 12 + (later.month - month)
        let completed = adding(months: months) > later ? months - 1 : months
        return max(0, completed)
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func length(ofMonth month: Int, in year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func gregorian(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
