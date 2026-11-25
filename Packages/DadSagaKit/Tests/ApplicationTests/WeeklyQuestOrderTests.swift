import Application
import Domain
import Foundation
import Testing

/// Over the weeks, a card comes back only after every other card on offer that week has come up since (ADR-0072).
@Suite("Weekly quest over the weeks")
struct WeeklyQuestOrderTests {
    typealias Fixture = WeeklyHighlightsUseCaseTests

    static func quest(_ id: String, world: String = "w1", from months: Int = 0, evergreen: Bool = false) -> Quest {
        Quest(
            id: id, worldID: world, title: Fixture.text, description: Fixture.text, skill: .care, xp: 15,
            minAgeMonths: months, isEvergreen: evergreen
        )
    }

    /// Six cards from birth, three more at one month; then World 2 from three months, with one of them evergreen.
    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w0", order: 0, title: Fixture.text, tagline: Fixture.text, span: .beforeBirth),
            World(id: "w1", order: 1, title: Fixture.text, tagline: Fixture.text, span: .months(min: 0, max: 2)),
            World(id: "w2", order: 2, title: Fixture.text, tagline: Fixture.text, span: .months(min: 3, max: 12))
        ],
        quests: (1...3).map { quest("z\($0)", world: "w0") }
            + (1...5).map { quest("a\($0)") } + [quest("e1", evergreen: true)]
            + (1...3).map { quest("b\($0)", from: 1) }
            + (1...4).map { quest("c\($0)", world: "w2", from: 3) },
        bosses: [],
        firsts: []
    )

    static let newborn: Set<String> = ["a1", "a2", "a3", "a4", "a5", "e1"]
    static let oneMonth: Set<String> = newborn.union(["b1", "b2", "b3"])
    static let threeMonths: Set<String> = ["c1", "c2", "c3", "c4", "e1"]

    /// Wednesday 4 March 2026; its week is the birth week.
    static let birthDay = CalendarDay.day(2026, 3, 4)
    static let children = (1...20).compactMap { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", $0)) }
    let progress = SpyProgressRepository()

    /// The Wednesday of a week, counted from the birth week.
    func wednesday(_ week: Int) -> Date {
        Fixture.date(2026, 3, 4).addingTimeInterval(Double(week) * 7 * 86_400)
    }

    /// Worked out by hand: one month on 4 April (a Saturday, so from week 5), three on 4 June (a Thursday, week 14).
    func offered(_ week: Int) -> Set<String> {
        switch week {
        case ..<5: Self.newborn
        case ..<14: Self.oneMonth
        default: Self.threeMonths
        }
    }

    func picks(_ childID: UUID, birthDay: CalendarDay? = Self.birthDay, weeks: [Int]) async throws -> [String] {
        let profiles = SpyProfileRepository()
        await profiles.seed(PlayerProfile(
            children: [Child(id: childID, name: "Lena", birthDay: birthDay)], heroClassID: "chef"
        ))
        let sut = DefaultGetWeeklyHighlightsUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            photoStore: SpyPhotoStore(),
            calendar: Fixture.calendar
        )
        var ids: [String] = []
        for week in weeks {
            let slot = try await sut.execute(childID: childID, on: wednesday(week), photoMaxPixelSize: nil)?.quest
            guard case .suggested(let quest, _) = slot else { continue }
            ids.append(quest.id)
        }
        return ids
    }

    @Test("Given cards that join with age and a new world, when the weeks pass, then a card returns only after the others")
    func growingPool() async throws {
        for child in Self.children {
            let shown = try await picks(child, weeks: Array(0..<40))
            #expect(shown.count == 40)
            for (week, id) in shown.enumerated() {
                #expect(offered(week).contains(id), "week \(week): \(id)")
                guard let before = shown[..<week].lastIndex(of: id) else { continue }
                let since = Set(shown[(before + 1)..<week])
                #expect(offered(week).subtracting([id]).isSubset(of: since), "week \(week): \(id) came back early")
            }
        }
    }

    @Test("Given any week, when asking out of order, or after doing quests, then each week's quest is the same")
    func askedInAnyOrder() async throws {
        let child = Self.children[0]
        let weeks = Array(0..<20)
        let shown = try await picks(child, weeks: weeks)

        for (week, id) in shown.enumerated() where week.isMultiple(of: 3) {
            try await progress.add(ProgressEvent(kind: .quest(id: id), childID: child, date: wednesday(week)))
        }
        let backwards = try await picks(child, weeks: weeks.reversed())

        #expect(backwards == shown.reversed())
    }

    @Test("Given a child not born yet, when the birth day is set, then the weeks before the birth week keep their quest")
    func birthKeepsTheWeeksBefore() async throws {
        let child = Self.children[0]
        let weeks = Array(-9 ..< 0)
        let unborn = try await picks(child, birthDay: nil, weeks: weeks)

        #expect(Set(unborn.prefix(3)) == ["z1", "z2", "z3"])
        #expect(try await picks(child, weeks: weeks) == unborn)
    }

    @Test("Given a child not born yet, when asking about weeks far back or ahead, then there is a quest")
    func farWeeks() async throws {
        #expect(try await picks(Self.children[0], birthDay: nil, weeks: [-1880, 3860]).count == 2)
    }

    @Test("Given two children, when the weeks pass, then their orders differ")
    func siblingsDiffer() async throws {
        let weeks = Array(0..<9)
        #expect(try await picks(Self.children[0], weeks: weeks) != picks(Self.children[1], weeks: weeks))
    }
}
