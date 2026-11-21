import Domain
import Foundation

/// A child born on 15 January 2024 (UTC), and content with the app's four worlds.
struct SagaFixtures {
    let calendar: Calendar
    let child: Child
    let sibling: Child
    let catalog: ContentCatalog
    var timeZone: TimeZone { calendar.timeZone }

    init(birth: DateComponents = DateComponents(year: 2024, month: 1, day: 15), worlds: [World]? = nil) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        self.calendar = calendar
        let birthDate = calendar.date(from: birth) ?? .distantPast
        child = Child(name: "Άννα", birthDay: CalendarDay(birthDate, in: .gmt))
        sibling = Child(name: "Νίκος", birthDay: CalendarDay(birthDate, in: .gmt))

        let text = Fixtures.text
        catalog = ContentCatalog(
            worlds: worlds ?? [
                World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8)),
                World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24)),
                World(id: "w3", order: 3, title: text, tagline: text, span: .months(min: 25, max: 41)),
                World(id: "w4", order: 4, title: text, tagline: text, span: .months(min: 42, max: 71))
            ],
            quests: [
                Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0)
            ],
            bosses: (1...40).map {
                BossFight(id: "b\($0)", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                          skill: .care, xp: 100, minAgeMonths: 0)
            },
            firsts: (1...30).map {
                FirstMoment(id: "f\($0)", order: $0, emoji: "😊", title: text, xp: 30, companionTrait: nil)
            }
        )
    }

    /// `months` and `days` after the start of the child's birth day, plus `hours`.
    func date(months: Int, days: Int = 0, hours: Int = 0) -> Date {
        let birthDay = child.birthDay?.start(in: calendar.timeZone) ?? .distantPast
        let month = calendar.date(byAdding: .month, value: months, to: birthDay) ?? .distantPast
        let day = calendar.date(byAdding: .day, value: days, to: month) ?? .distantPast
        return calendar.date(byAdding: .hour, value: hours, to: day) ?? .distantPast
    }

    func event(
        _ kind: ProgressEvent.Kind,
        months: Int,
        days: Int = 0,
        child: Child? = nil,
        photos: String...
    ) -> ProgressEvent {
        ProgressEvent(kind: kind, childID: (child ?? self.child).id, date: date(months: months, days: days), photoIDs: photos)
    }

    func storyboard(_ events: [ProgressEvent], period: SagaPeriod = .everything) -> SagaStoryboard? {
        SagaStoryboard.make(
            events: events, child: child, period: period, catalog: catalog, now: date(months: 80), timeZone: timeZone
        )
    }

    func occasion(
        _ events: [ProgressEvent],
        months: Int,
        days: Int = 0,
        hours: Int = 0,
        answered: Set<String> = []
    ) -> SagaOccasion? {
        SagaOccasions.latest(
            for: child, events: events, catalog: catalog, on: date(months: months, days: days, hours: hours),
            answered: answered, timeZone: timeZone
        )
    }
}
