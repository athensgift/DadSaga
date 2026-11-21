import Domain

extension CalendarDay {
    /// A day the test knows exists; a mistyped one reads as the earliest day, so the test fails rather than crashes.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day) ?? CalendarDay(.distantPast, in: .gmt)
    }
}
