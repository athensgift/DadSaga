import Domain
import Foundation
import Testing

@Suite("A child's age")
struct ChildAgeTests {
    @Test("Given a birth day picked in Auckland, when the phone is in Los Angeles, then the first birthday is on that day")
    func birthdayIsThePickedDay() throws {
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        var phone = Calendar(identifier: .gregorian)
        phone.timeZone = losAngeles
        let child = Child(name: "Άννα", birthDay: .day(2025, 3, 15))
        let catalog = SagaFixtures().catalog
        let april = try #require(phone.date(from: DateComponents(year: 2025, month: 4, day: 15, hour: 12)))
        let events = [ProgressEvent(kind: .quest(id: "q1"), childID: child.id, date: april)]
        let march14 = try #require(phone.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 12)))
        let march15 = try #require(phone.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 0)))

        let early = SagaOccasions.latest(for: child, events: events, catalog: catalog, on: march14, timeZone: losAngeles)
        let onTheDay = SagaOccasions.latest(for: child, events: events, catalog: catalog, on: march15, timeZone: losAngeles)

        #expect(early == nil)
        #expect(onTheDay?.kind == .birthday(years: 1))
        #expect(onTheDay?.date == march15)
    }

    @Test(
        "Given a birth on 31 January or 29 February, when counting every day for seven years, then age, years and worlds agree",
        arguments: [CalendarDay.day(2024, 1, 31), .day(2024, 2, 29)]
    )
    func oneAgeRule(_ birth: CalendarDay) throws {
        let saga = SagaFixtures()
        let child = Child(name: "Άννα", birthDay: birth)
        let zone = try #require(TimeZone(identifier: "Europe/Athens"))
        var day = birth
        while day < birth.adding(months: 84) {
            let age = try #require(child.age(on: day).months)
            let turned = try #require(child.day(atMonths: age))
            let next = try #require(child.day(atMonths: age + 1))
            #expect(turned <= day && day < next, "\(day)")
            let start = day.start(in: zone)
            let year = try #require(SagaPeriod.year(age / 12 + 1).interval(
                for: child, catalog: saga.catalog, now: start, timeZone: zone
            ))
            #expect(year.holds(start), "\(day)")
            let world = saga.catalog.worlds.first {
                SagaPeriod.world(id: $0.id).interval(for: child, catalog: saga.catalog, now: start, timeZone: zone)?
                    .holds(start) ?? false
            }
            let current = UnlockRules.isBeyondContent(saga.catalog, age: .months(age))
                ? nil
                : UnlockRules.currentWorld(in: saga.catalog, age: .months(age))
            #expect(world == current, "\(day)")
            day = day.adding(days: 1)
        }
    }
}

private extension DateInterval {
    func holds(_ date: Date) -> Bool { start <= date && date < end }
}
