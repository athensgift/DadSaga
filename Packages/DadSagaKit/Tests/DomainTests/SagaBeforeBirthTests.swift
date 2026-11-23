import Domain
import Foundation
import Testing

/// World 0 in the film (ADR-0053 §2): a period that ends on the birth day, its offer on that day, its chapter.
@Suite("Saga film before birth")
struct SagaBeforeBirthTests {
    static let text = Fixtures.text
    let saga = SagaFixtures(worlds: [
        World(id: "w0", order: 0, title: text, tagline: text, span: .beforeBirth),
        World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8)),
        World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: nil))
    ])

    var birth: Date { saga.date(months: 0) }

    @Test("Given a born child, when reading World 0's period, then it ends on the birth day; year 1 starts there")
    func worldZeroEndsAtBirth() throws {
        let world = try #require(SagaPeriod.world(id: "w0").interval(
            for: saga.child, catalog: saga.catalog, now: saga.date(months: 3), timeZone: saga.timeZone
        ))
        #expect(world.end == birth)
        let year = try #require(SagaPeriod.year(1).interval(
            for: saga.child, catalog: saga.catalog, now: saga.date(months: 3), timeZone: saga.timeZone
        ))
        #expect(year.start == birth)
    }

    @Test("Given a child not born yet, when reading periods, then World 0 is open, no year exists, and the film can tell it")
    func notBornPeriods() {
        let child = Child(id: saga.child.id, name: "Μπέμπης", birthDay: nil)
        let now = saga.date(months: 3)
        #expect(SagaPeriod.world(id: "w0").interval(for: child, catalog: saga.catalog, now: now, timeZone: saga.timeZone)?
            .end == .distantFuture)
        #expect(SagaPeriod.year(1).interval(for: child, catalog: saga.catalog, now: now, timeZone: saga.timeZone) == nil)
        #expect(SagaPeriod.world(id: "w1").interval(for: child, catalog: saga.catalog, now: now, timeZone: saga.timeZone) == nil)
        let events = [ProgressEvent(kind: .first(id: "f1"), childID: child.id, date: saga.date(months: 1))]
        #expect(SagaPeriod.available(for: child, events: events, catalog: saga.catalog, now: now, timeZone: saga.timeZone)
            == [.world(id: "w0"), .everything])
    }

    @Test("Given an entry before the birth, when the birth day comes, then home offers World 0's film; nothing before the birth")
    func offerOnTheBirthDay() throws {
        let before = saga.event(.first(id: "f1"), months: -2)
        let offer = try #require(saga.occasion([before], months: 0, hours: 10))
        #expect(offer.period == .world(id: "w0"))
        #expect(offer.date == birth)
        #expect(saga.occasion([before], months: 0, days: -1) == nil)
        let notBorn = Child(id: saga.child.id, name: "Μπέμπης", birthDay: nil)
        #expect(SagaOccasions.latest(for: notBorn, events: [before], catalog: saga.catalog, on: birth,
                                     timeZone: saga.timeZone) == nil)
        #expect(saga.occasion([saga.event(.first(id: "f1"), months: 1)], months: 0, hours: 10) == nil)
    }

    @Test("Given entries before and after the birth, when the whole saga is cut, then the ones before get World 0's chapter")
    func wholeSagaChapters() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: -3),
            saga.event(.first(id: "f2"), months: 2)
        ]))
        let chapters = storyboard.scenes.compactMap { scene -> String? in
            if case .chapter(let world, _) = scene.kind { world.id } else { nil }
        }
        #expect(chapters == ["w0", "w1"])
        #expect(storyboard.span.start == saga.date(months: -3))
    }

    @Test("Given a child not born yet, when their film is cut, then it is told as before birth and starts at the first entry")
    func notBornFilm() throws {
        let child = Child(id: saga.child.id, name: "Μπέμπης", birthDay: nil)
        let first = saga.date(months: 1, days: 3)
        let storyboard = try #require(SagaStoryboard.make(
            events: [ProgressEvent(kind: .first(id: "f1"), childID: child.id, date: first)],
            cast: SagaCast(hero: .testDad, child: child),
            period: .everything, catalog: saga.catalog, now: saga.date(months: 4), timeZone: saga.timeZone
        ))
        #expect(storyboard.childAge == .beforeBirth)
        #expect(storyboard.span.start == CalendarDay(first, in: saga.timeZone).start(in: saga.timeZone))
    }

    @Test("Given an entry on the birth day in Athens, still the day before in GMT, when cut in Athens, then it is World 1's")
    func birthDayInThePhonesZone() throws {
        let athens = try #require(TimeZone(identifier: "Europe/Athens"))
        let child = Child(name: "Άννα", birthDay: .day(2026, 6, 10))
        // 00:30 on 10 June in Athens (UTC+3) is 21:30 on 9 June in GMT.
        let entry = try #require(child.birthDay?.start(in: athens)).addingTimeInterval(30 * 60)
        #expect(CalendarDay(entry, in: .gmt) == .day(2026, 6, 9))
        let events = [ProgressEvent(kind: .first(id: "f1"), childID: child.id, date: entry)]
        let now = entry.addingTimeInterval(40 * 86_400)

        let storyboard = try #require(SagaStoryboard.make(
            events: events
                + [ProgressEvent(kind: .first(id: "f2"), childID: child.id, date: entry.addingTimeInterval(-86_400))],
            cast: SagaCast(hero: .testDad, child: child),
            period: .everything, catalog: saga.catalog, now: now, timeZone: athens
        ))
        let chapters = storyboard.scenes.compactMap { scene -> String? in
            if case .chapter(let world, _) = scene.kind { world.id } else { nil }
        }
        #expect(chapters == ["w0", "w1"])
        let harbour = try #require(SagaPeriod.world(id: "w0").interval(
            for: child, catalog: saga.catalog, now: now, timeZone: athens
        ))
        #expect(!harbour.contains(entry))
        #expect(try #require(SagaPeriod.world(id: "w1").interval(
            for: child, catalog: saga.catalog, now: now, timeZone: athens
        )).contains(entry))
    }
}
