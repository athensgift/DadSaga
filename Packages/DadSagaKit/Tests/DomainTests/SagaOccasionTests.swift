import Domain
import Foundation
import Testing

@Suite("SagaOccasions")
struct SagaOccasionTests {
    let saga = SagaFixtures()

    @Test("Given an entry in the second year, when the second birthday comes, then it shows for 30 days, never before")
    func birthdayWindow() {
        let events = [saga.event(.quest(id: "q1"), months: 18)]

        #expect(saga.occasion(events, months: 24, days: -1) == nil)
        #expect(saga.occasion(events, months: 24)?.kind == .birthday(years: 2))
        #expect(saga.occasion(events, months: 24, days: 29)?.period == .year(2))
        #expect(saga.occasion(events, months: 24, days: 30) == nil)
    }

    @Test("Given a child born on 29 February, when they turn one, then the birthday shows on 28 February")
    func leapDayBirthday() throws {
        let leap = SagaFixtures(birth: DateComponents(year: 2024, month: 2, day: 29))
        let events = [leap.event(.quest(id: "q1"), months: 6)]
        let feb28 = try #require(leap.calendar.date(from: DateComponents(year: 2025, month: 2, day: 28)))

        let occasion = SagaOccasions.latest(
            for: leap.child, events: events, catalog: leap.catalog, on: feb28, calendar: leap.calendar
        )

        #expect(occasion?.kind == .birthday(years: 1))
    }

    @Test("Given an entry in the first world, when the child turns 9 months, then it offers the world they left")
    func newWorldAtMaxPlusOne() {
        let events = [saga.event(.first(id: "f1"), months: 3)]

        #expect(saga.occasion(events, months: 9, days: -1) == nil)
        let occasion = saga.occasion(events, months: 9)
        #expect(occasion?.kind == .newWorld(left: saga.catalog.worlds[0]))
        #expect(occasion?.period == .world(id: "w1"))
    }

    @Test("Given a second birthday and a new world a month later, when both show, then the newest wins")
    func newestWins() {
        let events = [saga.event(.quest(id: "q1"), months: 20)]
        func occasion(months: Int) -> SagaOccasion? {
            SagaOccasions.latest(
                for: saga.child, events: events, catalog: saga.catalog, on: saga.date(months: months, days: 1),
                calendar: saga.calendar, windowDays: 60
            )
        }

        #expect(occasion(months: 24)?.kind == .birthday(years: 2))
        #expect(occasion(months: 25)?.kind == .newWorld(left: saga.catalog.worlds[1]))
    }

    @Test("Given an entry in the last world, when the child grows past it at 72 months, then it still offers it")
    func leavingTheLastWorld() {
        let events = [saga.event(.quest(id: "q1"), months: 50)]
        #expect(saga.occasion(events, months: 72, days: 1)?.kind == .newWorld(left: saga.catalog.worlds[3]))
    }

    @Test("Given an entry in the sixth year, when the sixth birthday is also the last world's end, then the world wins")
    func sameDayWorldWins() {
        let events = [saga.event(.quest(id: "q1"), months: 66), saga.event(.quest(id: "q1"), months: 50)]
        #expect(saga.occasion(events, months: 72)?.kind == .newWorld(left: saga.catalog.worlds[3]))
    }

    @Test("Given a child past the last world, when they turn seven, then the birthday is still offered")
    func birthdayAfterTheContent() {
        let events = [saga.event(.quest(id: "q1"), months: 80)]
        #expect(saga.occasion(events, months: 84)?.kind == .birthday(years: 7))
    }

    @Test("Given a birth date entered in the afternoon, when the birthday morning comes, then the offer shows")
    func birthdayFromMidnight() {
        let afternoon = SagaFixtures(birth: DateComponents(year: 2024, month: 1, day: 15, hour: 14, minute: 37))
        let events = [afternoon.event(.quest(id: "q1"), months: 18)]

        #expect(afternoon.occasion(events, months: 24, hours: 8)?.kind == .birthday(years: 2))
        #expect(afternoon.occasion(events, months: 24, hours: -1) == nil)
    }

    @Test("Given the dad answered the newest occasion, when an older one still shows, then nothing is offered")
    func answeredMeansNone() throws {
        let events = [saga.event(.quest(id: "q1"), months: 20)]
        func occasion(answered: Set<String>) -> SagaOccasion? {
            SagaOccasions.latest(
                for: saga.child, events: events, catalog: saga.catalog, on: saga.date(months: 25, days: 1),
                answered: answered, calendar: saga.calendar, windowDays: 60
            )
        }
        let newest = try #require(occasion(answered: []))

        #expect(occasion(answered: [newest.id]) == nil)
    }

    @Test("Given a world with no end, when the child is in it, then it is never offered as left")
    func openEndedWorld() {
        let text = Fixtures.text
        let open = SagaFixtures(worlds: [
            World(id: "w1", order: 1, title: text, tagline: text, minAgeMonths: 0, maxAgeMonths: nil)
        ])
        let events = [open.event(.quest(id: "q1"), months: 3)]

        #expect(open.occasion(events, months: 9) == nil)
        #expect(open.occasion(events, months: 12)?.kind == .birthday(years: 1))
    }

    @Test("Given no entry of this child in the period, when the day comes, then nothing is offered")
    func nothingWithoutEntries() {
        #expect(saga.occasion([], months: 24) == nil)
        #expect(saga.occasion([saga.event(.quest(id: "q1"), months: 18, child: saga.sibling)], months: 24) == nil)
        #expect(saga.occasion([saga.event(.quest(id: "q1"), months: 6)], months: 24) == nil)
    }

    @Test("Given two occasions, when comparing ids, then each is stable and its own")
    func stableIDs() throws {
        let events = [saga.event(.quest(id: "q1"), months: 20)]
        let birthday = try #require(saga.occasion(events, months: 24))
        let world = try #require(saga.occasion(events, months: 25, days: 1))

        #expect(birthday.id == saga.occasion(events, months: 24, days: 5)?.id)
        #expect(birthday.id != world.id)
        #expect(birthday.childID == saga.child.id)
    }

    // MARK: A family

    /// Νίκος is born `days` after Άννα.
    func brother(bornDaysLater days: Int) -> Child {
        Child(name: "Νίκος", birthDate: saga.date(months: 0, days: days))
    }

    func familyOccasion(
        _ children: [Child], _ events: [ProgressEvent], months: Int, days: Int = 0, answered: Set<String> = []
    ) -> SagaOccasion? {
        SagaOccasions.latest(
            forFamily: children, events: events, catalog: saga.catalog, on: saga.date(months: months, days: days),
            answered: answered, calendar: saga.calendar
        )
    }

    @Test("Given Anna's birthday today and Niko's ten days ago, when home looks, then Anna's is offered")
    func newestOfTheFamily() {
        let niko = brother(bornDaysLater: -10)
        let events = [saga.event(.quest(id: "q1"), months: 18), saga.event(.quest(id: "q1"), months: 18, child: niko)]

        let occasion = familyOccasion([niko, saga.child], events, months: 24)

        #expect(occasion?.childID == saga.child.id)
        #expect(occasion?.kind == .birthday(years: 2))
    }

    @Test("Given the dad answered Anna's newer occasion, when Niko's older one still shows, then nothing is offered")
    func anOlderSiblingOccasionNeverReplaces() throws {
        let niko = brother(bornDaysLater: -10)
        let events = [saga.event(.quest(id: "q1"), months: 18), saga.event(.quest(id: "q1"), months: 18, child: niko)]
        let annas = try #require(familyOccasion([niko, saga.child], events, months: 24))

        #expect(familyOccasion([niko, saga.child], events, months: 24, answered: [annas.id]) == nil)
    }

    @Test("Given twins with a birthday today, when the first twin's is answered, then the second's shows; then none")
    func twins() throws {
        let twin = saga.sibling
        let events = [saga.event(.quest(id: "q1"), months: 18), saga.event(.first(id: "f1"), months: 20, child: twin)]
        let family = [saga.child, twin]

        let first = try #require(familyOccasion(family, events, months: 24, days: 3))
        #expect(first.childID == saga.child.id)

        let second = try #require(familyOccasion(family, events, months: 24, days: 3, answered: [first.id]))
        #expect(second.childID == twin.id)
        #expect(second.kind == .birthday(years: 2))

        #expect(familyOccasion(family, events, months: 24, days: 3, answered: [first.id, second.id]) == nil)
    }

    @Test("Given a birthday today for a child with nothing in that year, when home looks, then a sibling's older one shows")
    func emptyPeriodsDoNotCount() {
        let niko = brother(bornDaysLater: -10)
        let events = [saga.event(.quest(id: "q1"), months: 18, child: niko)]

        #expect(familyOccasion([saga.child, niko], events, months: 24)?.childID == niko.id)
        #expect(familyOccasion([saga.child], events, months: 24) == nil)
        #expect(familyOccasion([], events, months: 24) == nil)
    }
}
