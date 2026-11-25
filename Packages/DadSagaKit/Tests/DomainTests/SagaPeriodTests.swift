import Domain
import Foundation
import Testing

@Suite("SagaPeriod")
struct SagaPeriodTests {
    let saga = SagaFixtures()

    func interval(_ period: SagaPeriod, nowMonths: Int = 80) -> DateInterval? {
        period.interval(for: saga.child, catalog: saga.catalog, now: saga.date(months: nowMonths), timeZone: saga.timeZone)
    }

    @Test("Given the second year, when asking its interval, then it runs from the first birthday to the second")
    func year() {
        #expect(interval(.year(2)) == DateInterval(start: saga.date(months: 12), end: saga.date(months: 24)))
    }

    @Test("Given a world, when asking its interval, then it runs from its minimum age to the month after its maximum")
    func world() {
        #expect(interval(.world(id: "w2")) == DateInterval(start: saga.date(months: 9), end: saga.date(months: 24)))
    }

    @Test("Given a year below one, a year not started, or an unknown world, when asking, then there is no interval")
    func none() {
        #expect(interval(.year(0)) == nil)
        #expect(interval(.year(3), nowMonths: 20) == nil)
        #expect(interval(.world(id: "gone")) == nil)
    }

    @Test("Given a 26-month-old with entries in each stretch, when listing periods, then the years, worlds and everything")
    func available() {
        let events = [3, 14, 25].map { saga.event(.quest(id: "q1"), months: $0) }
        let periods = SagaPeriod.available(
            for: saga.child, events: events, catalog: saga.catalog, now: saga.date(months: 26), timeZone: saga.timeZone
        )
        #expect(periods == [.year(1), .year(2), .year(3), .world(id: "w1"), .world(id: "w2"), .world(id: "w3"), .everything])
    }

    @Test("Given entries only in the first months and another child's later, when listing periods, then empty ones are left out")
    func emptyPeriodsLeftOut() {
        let events = [saga.event(.quest(id: "q1"), months: 3), saga.event(.quest(id: "q1"), months: 14, child: saga.sibling)]
        let periods = SagaPeriod.available(
            for: saga.child, events: events, catalog: saga.catalog, now: saga.date(months: 26), timeZone: saga.timeZone
        )
        #expect(periods == [.year(1), .world(id: "w1"), .everything])
    }

    @Test("Given a world with no end or with its ages reversed, when asking, then it runs on, or there is none")
    func openAndBrokenWorlds() {
        let text = Fixtures.text
        let odd = SagaFixtures(worlds: [
            World(id: "open", order: 1, title: text, tagline: text, span: .months(min: 0, max: nil)),
            World(id: "broken", order: 2, title: text, tagline: text, span: .months(min: 10, max: 4))
        ])
        let now = odd.date(months: 20)

        #expect(SagaPeriod.world(id: "open").interval(for: odd.child, catalog: odd.catalog, now: now, timeZone: odd.timeZone)?
            .end == .distantFuture)
        #expect(SagaPeriod.world(id: "broken").interval(for: odd.child, catalog: odd.catalog, now: now, timeZone: odd.timeZone)
            == nil)
    }

    @Test("Given a newborn with a first entry, when listing periods, then the first year, the first world, and everything")
    func availableForANewborn() {
        let periods = SagaPeriod.available(
            for: saga.child, events: [saga.event(.quest(id: "q1"), months: 0, days: 1)], catalog: saga.catalog,
            now: saga.date(months: 0, days: 3), timeZone: saga.timeZone
        )
        #expect(periods == [.year(1), .world(id: "w1"), .everything])
    }

    @Test("Given a birth date entered in the afternoon, when asking the first year, then it starts at midnight")
    func yearsStartAtMidnight() {
        let afternoon = SagaFixtures(birth: DateComponents(year: 2024, month: 1, day: 15, hour: 14))
        let year = SagaPeriod.year(1).interval(
            for: afternoon.child, catalog: afternoon.catalog, now: afternoon.date(months: 30), timeZone: afternoon.timeZone
        )
        #expect(year == DateInterval(start: afternoon.date(months: 0), end: afternoon.date(months: 12)))
        #expect(afternoon.calendar.component(.hour, from: afternoon.date(months: 12)) == 0)
    }

    @Test("Given no entries yet, when listing periods, then only everything")
    func availableWithNothing() {
        let periods = SagaPeriod.available(
            for: saga.child, events: [], catalog: saga.catalog, now: saga.date(months: 26), timeZone: saga.timeZone
        )
        #expect(periods == [.everything])
    }
}
