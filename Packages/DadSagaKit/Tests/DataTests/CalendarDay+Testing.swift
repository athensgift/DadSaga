import Domain
import Foundation

extension CalendarDay {
    /// A day the test knows exists; a mistyped one reads as the earliest day, so the test fails rather than crashes.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day) ?? CalendarDay(.distantPast, in: .gmt)
    }
}

extension CalendarDay {
    /// The day a birth moment stored before version 5 becomes: the day it falls on in the phone's time zone, as the
    /// migration reads it (ADR-0048 §3).
    static func migrated(_ secondsSince1970: TimeInterval) -> CalendarDay {
        CalendarDay(Date(timeIntervalSince1970: secondsSince1970), in: .autoupdatingCurrent)
    }
}
