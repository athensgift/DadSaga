import Domain
import Foundation
import Testing

@Suite("WeeklyQuest")
struct WeeklyQuestTests {
    static let text = LocalizedText(el: "x", en: "x")

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    static func quest(_ id: String) -> Quest {
        Quest(id: id, worldID: "w1", title: text, description: text, skill: .care, xp: 15, minAgeMonths: 0)
    }

    let pool = (1...6).map { Self.quest("q\($0)") }
    let child = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()
    let sibling = UUID(uuidString: "99999999-8888-7777-6666-555555555555") ?? UUID()

    /// The quest of a child born on 1 January 2026, offered the same cards all year.
    func pick(on date: Date, for childID: UUID? = nil, from pool: [Quest]? = nil) -> Quest? {
        let world = World(
            id: "w1", order: 1, title: Self.text, tagline: Self.text, span: .months(min: 0, max: 24)
        )
        return WeeklyQuest.pick(
            for: Child(id: childID ?? child, name: "Lena", birthDay: CalendarDay(year: 2026, month: 1, day: 1)),
            family: .everyone,
            in: ContentCatalog(worlds: [world], quests: pool ?? self.pool, bosses: [], firsts: []),
            week: WeeklyQuest.week(containing: date, calendar: Self.calendar),
            calendar: Self.calendar
        )
    }

    @Test("Given any day of one week, when picking, then the quest is the same")
    func sameAllWeek() {
        let monday = pick(on: Self.date(2026, 11, 16, 0, 0))
        for day in 16...22 {
            #expect(pick(on: Self.date(2026, 11, day)) == monday)
        }
    }

    @Test("Given Sunday just before midnight, when finding its week, then it belongs to the week that began on Monday")
    func sundayNight() {
        let week = WeeklyQuest.week(containing: Self.date(2026, 11, 22, 23, 59), calendar: Self.calendar)
        #expect(week.start == Self.date(2026, 11, 16, 0, 0))
        #expect(week.end == Self.date(2026, 11, 23, 0, 0))
    }

    @Test("Given consecutive weeks, when picking, then every card comes up once before any repeats")
    func everyCardOnce() {
        let start = Self.date(2026, 11, 16)
        let picks = (0..<pool.count).compactMap { offset in
            pick(on: start.addingTimeInterval(Double(offset) * 7 * 24 * 60 * 60))
        }
        #expect(Set(picks.map(\.id)) == Set(pool.map(\.id)))
        let next = pick(on: start.addingTimeInterval(Double(pool.count) * 7 * 24 * 60 * 60))
        #expect(next == picks.first)
    }

    @Test("Given fixed inputs, when picking, then the quests are known ones, so every process agrees")
    func stableAcrossProcesses() {
        let weeks = (0..<6).map { Self.date(2026, 11, 18).addingTimeInterval(Double($0) * 7 * 86_400) }
        #expect(weeks.map { pick(on: $0)?.id } == ["q6", "q4", "q2", "q5", "q1", "q3"])
    }

    /// The last five are zones whose rules changed after 2001: three where the week can start on the day the clocks go
    /// back, two that skipped a day in 2011.
    static let zones = [
        "America/New_York", "Atlantic/Azores", "Europe/Athens", "Pacific/Auckland",
        "America/Ojinaga", "America/North_Dakota/Beulah", "America/North_Dakota/New_Salem",
        "Pacific/Apia", "Pacific/Fakaofo"
    ]

    @Test(
        "Given a child not born yet, when the dad travels, then the week and its quest stay, week after week",
        arguments: zones, [1, 2, 7]
    )
    func sameInEveryTimeZone(_ identifier: String, firstWeekday: Int) throws {
        var here = Self.calendar
        here.firstWeekday = firstWeekday
        var there = here
        there.timeZone = try #require(TimeZone(identifier: identifier))
        let world = World(id: "w1", order: 0, title: Self.text, tagline: Self.text, span: .beforeBirth)
        let catalog = ContentCatalog(worlds: [world], quests: pool, bosses: [], firsts: [])
        let coming = Child(id: child, name: "Lena", birthDay: nil)
        let first = try #require(CalendarDay(year: 2026, month: 11, day: 18))

        // Two years of Wednesdays at noon, so every clock change is crossed.
        for offset in 0..<110 {
            let wednesday = first.adding(days: 7 * offset)
            let noon = { (calendar: Calendar) in wednesday.start(in: calendar.timeZone).addingTimeInterval(12 * 3_600) }
            let home = WeeklyQuest.week(containing: noon(here), calendar: here)
            let away = WeeklyQuest.week(containing: noon(there), calendar: there)

            #expect(
                WeeklyQuest.weekNumber(of: away, calendar: there) == WeeklyQuest.weekNumber(of: home, calendar: here),
                "the week of \(wednesday)"
            )
            #expect(
                WeeklyQuest.pick(for: coming, family: .everyone, in: catalog, week: away, calendar: there)
                    == WeeklyQuest.pick(for: coming, family: .everyone, in: catalog, week: home, calendar: here)
            )
        }
    }

    @Test("Given two siblings, when picking over the weeks, then their orders differ")
    func siblingsDiffer() {
        let start = Self.date(2026, 11, 16)
        let weeks = (0..<pool.count).map { start.addingTimeInterval(Double($0) * 7 * 24 * 60 * 60) }
        #expect(weeks.map { pick(on: $0)?.id } != weeks.map { pick(on: $0, for: sibling)?.id })
    }

    @Test("Given an empty pool, when picking, then there is no quest")
    func emptyPool() {
        #expect(pick(on: Self.date(2026, 11, 18), from: []) == nil)
    }

    @Test("Given completions, when checking this week, then only this child's and this week's count")
    func doneThisWeekOnly() {
        let quest = pool[0]
        let week = WeeklyQuest.week(containing: Self.date(2026, 11, 18), calendar: Self.calendar)
        let lastWeek = ProgressEvent(kind: .quest(id: quest.id), childID: child, date: Self.date(2026, 11, 15, 23, 59))
        let sibling = ProgressEvent(kind: .quest(id: quest.id), childID: sibling, date: Self.date(2026, 11, 17))
        let other = ProgressEvent(kind: .quest(id: "q2"), childID: child, date: Self.date(2026, 11, 17))
        #expect(!WeeklyQuest.isDone(quest, childID: child, week: week, events: [lastWeek, sibling, other]))

        let done = ProgressEvent(kind: .quest(id: quest.id), childID: child, date: Self.date(2026, 11, 22, 23, 59))
        #expect(WeeklyQuest.isDone(quest, childID: child, week: week, events: [lastWeek, done]))
    }
}
