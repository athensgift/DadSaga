import Domain
import Foundation
import Testing

@Suite("WeeklyReminder")
struct WeeklyReminderTests {
    static func calendar(_ zone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in calendar: Calendar = calendar()) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @Test("Given the default on a Wednesday, when asking for the next date, then it is Saturday at 10:00")
    func nextSaturday() {
        let dates = WeeklyReminder.default.nextDates(after: Self.date(11, 18, 12), count: 1, calendar: Self.calendar())
        #expect(dates == [Self.date(11, 21, 10)])
    }

    @Test("Given Saturday at exactly 10:00, when asking for the next date, then it is the following Saturday")
    func strictlyAfter() {
        let dates = WeeklyReminder.default.nextDates(after: Self.date(11, 21, 10), count: 1, calendar: Self.calendar())
        #expect(dates == [Self.date(11, 28, 10)])
    }

    @Test("Given Sunday 18:30, when asking from Sunday morning, then it is that same evening")
    func customDayAndTime() {
        let reminder = WeeklyReminder(isEnabled: true, weekday: 1, hour: 18, minute: 30, wasOffered: true)
        let dates = reminder.nextDates(after: Self.date(11, 22, 9), count: 1, calendar: Self.calendar())
        #expect(dates == [Self.date(11, 22, 18, 30)])
    }

    @Test("Given Athens time, when four dates cross the end of summer time, then each stays at 10:00 local")
    func acrossDaylightSaving() {
        let athens = Self.calendar("Europe/Athens")
        let dates = WeeklyReminder.default.nextDates(after: Self.date(10, 14, 12, in: athens), count: 4, calendar: athens)
        #expect(dates == [17, 24, 31].map { Self.date(10, $0, 10, in: athens) } + [Self.date(11, 7, 10, in: athens)])
    }

    @Test("Given out-of-range values, when creating, then they are clamped to a real day and time")
    func clamps() {
        let reminder = WeeklyReminder(isEnabled: true, weekday: 9, hour: 25, minute: -3, wasOffered: false)
        #expect(reminder.weekday == 7)
        #expect(reminder.hour == 23)
        #expect(reminder.minute == 0)
    }
}
