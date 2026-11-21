import Domain
import Foundation
import Testing

@Suite("CalendarDay")
struct CalendarDayTests {
    @Test("Given days the Gregorian calendar doesn't have, when making them, then they are rejected")
    func invalidDaysAreRejected() {
        #expect(CalendarDay(year: 2025, month: 2, day: 30) == nil)
        #expect(CalendarDay(year: 2025, month: 2, day: 29) == nil)
        #expect(CalendarDay(year: 2025, month: 13, day: 1) == nil)
        #expect(CalendarDay(year: 2024, month: 2, day: 29) != nil)
        #expect(CalendarDay(year: 2000, month: 2, day: 29) != nil)
        #expect(CalendarDay(year: 1900, month: 2, day: 29) == nil)
    }

    @Test("Given one moment, when reading its day in Auckland and in Los Angeles, then the days differ")
    func dayDependsOnTheZone() throws {
        let auckland = try #require(TimeZone(identifier: "Pacific/Auckland"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let moment = Date(timeIntervalSince1970: 1_741_951_800) // 15 March 2025, 00:30 in Auckland.

        #expect(CalendarDay(moment, in: auckland) == .day(2025, 3, 15))
        #expect(CalendarDay(moment, in: losAngeles) == .day(2025, 3, 14))
    }

    @Test(
        "Given a day and a zone, when finding its start, then the start falls on that day, even where midnight is skipped",
        arguments: [
            ("Europe/Athens", CalendarDay.day(2026, 3, 29)),
            ("America/Santiago", .day(2026, 9, 6)),
            ("America/Sao_Paulo", .day(2018, 11, 4)),
            ("Pacific/Auckland", .day(2025, 3, 15)),
            ("UTC", .day(2024, 2, 29))
        ]
    )
    func startFallsOnTheSameDay(_ identifier: String, _ day: CalendarDay) throws {
        let zone = try #require(TimeZone(identifier: identifier))
        let start = day.start(in: zone)
        #expect(CalendarDay(start, in: zone) == day)
        #expect(CalendarDay(start.addingTimeInterval(-1), in: zone) == day.adding(days: -1))
    }

    @Test("Given a day late in a month, when adding months, then a shorter month ends on its last day")
    func addingMonthsClamps() {
        #expect(CalendarDay.day(2025, 1, 31).adding(months: 1) == .day(2025, 2, 28))
        #expect(CalendarDay.day(2024, 1, 31).adding(months: 1) == .day(2024, 2, 29))
        #expect(CalendarDay.day(2024, 2, 29).adding(months: 12) == .day(2025, 2, 28))
        #expect(CalendarDay.day(2024, 2, 29).adding(months: 48) == .day(2028, 2, 29))
        #expect(CalendarDay.day(2024, 11, 15).adding(months: 14) == .day(2026, 1, 15))
    }

    @Test("Given two days, when counting completed months, then a month is complete on the day it is reached")
    func completedMonths() {
        let birth = CalendarDay.day(2025, 1, 31)
        #expect(birth.months(until: .day(2025, 2, 27)) == 0)
        #expect(birth.months(until: .day(2025, 2, 28)) == 1)
        #expect(birth.months(until: .day(2025, 3, 30)) == 1)
        #expect(birth.months(until: .day(2025, 3, 31)) == 2)
        #expect(birth.months(until: .day(2024, 12, 1)) == 0)
        #expect(birth.months(until: birth) == 0)
    }

    @Test("Given days across a year's end and a leap day, when adding days, then the calendar is followed")
    func addingDays() {
        #expect(CalendarDay.day(2024, 12, 31).adding(days: 1) == .day(2025, 1, 1))
        #expect(CalendarDay.day(2024, 2, 28).adding(days: 1) == .day(2024, 2, 29))
        #expect(CalendarDay.day(2025, 3, 1).adding(days: -1) == .day(2025, 2, 28))
    }
}
