import Application
import Domain
import Foundation
import Testing

@Suite("GetWeeklyHighlightsUseCase")
struct WeeklyHighlightsUseCaseTests {
    static let text = LocalizedText(el: "x", en: "x")

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: 8)),
            World(id: "w2", order: 2, title: text, tagline: text, span: .months(min: 9, max: 24))
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: text, description: text, skill: .care, xp: 15, minAgeMonths: 0),
            Quest(id: "q2", worldID: "w2", title: text, description: text, skill: .play, xp: 15, minAgeMonths: 9)
        ],
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: [
            FirstMoment(id: "f1", order: 1, emoji: "👣", title: text, xp: 30, companionTrait: nil),
            FirstMoment(id: "f2", order: 2, emoji: "🗣️", title: text, xp: 30, companionTrait: nil)
        ]
    )

    /// Wednesday; the week runs from Monday 16 to Monday 23 November 2026.
    let today = Self.date(2026, 11, 18)
    /// Eight months old on Monday 16 (world 1), nine on Thursday 19 (world 2).
    let baby = Child(name: "Lena", birthDay: CalendarDay(Self.date(2026, 2, 19, 0), in: .gmt))
    let toddler = Child(name: "Nikos", birthDay: CalendarDay(Self.date(2025, 1, 1), in: .gmt))
    let profiles = SpyProfileRepository()
    let progress = SpyProgressRepository()
    let photos = SpyPhotoStore()

    var sut: DefaultGetWeeklyHighlightsUseCase {
        DefaultGetWeeklyHighlightsUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            photoStore: photos,
            calendar: Self.calendar
        )
    }

    func onboard(_ children: [Child]) async throws {
        await profiles.seed(PlayerProfile(children: children, heroClassID: "chef"))
    }

    @Test("Given no profile yet, when executing, then there is nothing to show")
    func noProfile() async throws {
        #expect(try await sut.execute(childID: nil, on: today, photoMaxPixelSize: nil) == nil)
    }

    @Test("Given a child that left the family, when executing, then the first child is shown")
    func unknownChildFallsBack() async throws {
        try await onboard([toddler, baby])

        let highlights = try await sut.execute(childID: UUID(), on: today, photoMaxPixelSize: nil)

        #expect(highlights?.child == toddler)
        #expect(highlights?.childCount == 2)
    }

    @Test("Given a birthday in the middle of the week, when executing, then the quest is still from the week's start")
    func birthdayMidWeek() async throws {
        try await onboard([baby])

        let thursday = try await sut.execute(childID: baby.id, on: Self.date(2026, 11, 19), photoMaxPixelSize: nil)

        #expect(thursday?.quest == .suggested(Self.catalog.quests[0], isDone: false))
        #expect(thursday?.validUntil == Self.date(2026, 11, 23, 0))
    }

    /// World 0 before birth, then the same worlds of months.
    static let catalogFromBeforeBirth = ContentCatalog(
        worlds: [World(id: "w0", order: 0, title: text, tagline: text, span: .beforeBirth)] + catalog.worlds,
        quests: [
            Quest(id: "q0", worldID: "w0", title: text, description: text, skill: .care, xp: 15, minAgeMonths: 0)
        ] + catalog.quests,
        bosses: [],
        firsts: []
    )

    @Test(
        "Given a baby born in the middle of the week, when executing, then the week's quest is for after the birth",
        arguments: [16, 18, 22]
    )
    func bornThisWeek(_ day: Int) async throws {
        // The week began on Monday 16, before the birth on Wednesday 18.
        try await onboard([Child(name: "Lena", birthDay: .day(2026, 11, 18))])
        let sut = DefaultGetWeeklyHighlightsUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalogFromBeforeBirth)),
            profileRepository: profiles,
            progressRepository: progress,
            photoStore: photos,
            calendar: Self.calendar
        )

        let highlights = try await sut.execute(childID: nil, on: Self.date(2026, 11, day), photoMaxPixelSize: nil)

        guard case .suggested(let quest, _) = highlights?.quest else {
            Issue.record("Expected a quest")
            return
        }
        #expect(quest.id == "q1")
    }

    @Test("Given the quest was done with this child this week, when executing, then it is marked done")
    func doneThisWeek() async throws {
        let baby = Child(name: "Lena", birthDay: CalendarDay(Self.date(2026, 6, 1), in: .gmt))
        try await onboard([baby, toddler])
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: toddler.id, date: today))
        let highlights = try await sut.execute(childID: baby.id, on: today, photoMaxPixelSize: nil)
        #expect(highlights?.quest == .suggested(Self.catalog.quests[0], isDone: false))

        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: baby.id, date: Self.date(2026, 11, 16)))

        let done = try await sut.execute(childID: baby.id, on: today, photoMaxPixelSize: nil)
        #expect(done?.quest == .suggested(Self.catalog.quests[0], isDone: true))
    }

    @Test("Given the partner did the week's quest and captured a first, when executing, then it isn't done; the moment shows")
    func partnersQuestIsntHis() async throws {
        let baby = Child(name: "Lena", birthDay: CalendarDay(Self.date(2026, 6, 1), in: .gmt))
        try await onboard([baby])
        try await progress.add(ProgressEvent(
            authorID: .partner, kind: .quest(id: "q1"), childID: baby.id, date: Self.date(2026, 11, 16)
        ))
        try await progress.add(ProgressEvent(
            authorID: .partner, kind: .first(id: "f1"), childID: baby.id, date: Self.date(2026, 11, 17)
        ))

        let highlights = try await sut.execute(childID: baby.id, on: today, photoMaxPixelSize: nil)

        #expect(highlights?.quest == .suggested(Self.catalog.quests[0], isDone: false))
        #expect(highlights?.latestMoment?.authorID == .partner)
    }

    @Test("Given a child older than every world, when executing, then adventures are coming and the moment stays")
    func beyondContent() async throws {
        let older = Child(name: "Eleni", birthDay: CalendarDay(Self.date(2020, 1, 1), in: .gmt))
        try await onboard([older])
        try await progress.add(ProgressEvent(kind: .first(id: "f1"), childID: older.id, date: Self.date(2021, 5, 1)))

        let highlights = try await sut.execute(childID: older.id, on: today, photoMaxPixelSize: nil)

        #expect(highlights?.quest == .comingSoon)
        #expect(highlights?.latestMoment?.first.id == "f1")
    }

    @Test("Given moments of several children, when executing, then only this child's newest one is shown")
    func latestMomentOfThisChild() async throws {
        try await onboard([toddler, baby])
        try await progress.add(ProgressEvent(kind: .first(id: "f1"), childID: toddler.id, date: Self.date(2026, 1, 1)))
        try await progress.add(ProgressEvent(kind: .first(id: "f2"), childID: toddler.id, date: Self.date(2026, 6, 1)))
        try await progress.add(ProgressEvent(kind: .first(id: "f1"), childID: baby.id, date: Self.date(2026, 11, 1)))

        let highlights = try await sut.execute(childID: toddler.id, on: today, photoMaxPixelSize: nil)

        #expect(highlights?.latestMoment?.first.id == "f2")
    }

    @Test("Given a moment with two photos, when a thumbnail is asked for, then only the cover's thumbnail is loaded")
    func photoThumbnail() async throws {
        try await onboard([toddler])
        let cover = try await photos.save(Data("jpeg".utf8))
        let other = try await photos.save(Data("other".utf8))
        try await progress.add(ProgressEvent(
            kind: .first(id: "f1"), childID: toddler.id, date: Self.date(2026, 6, 1), photoIDs: [cover, other]
        ))

        let withPhoto = try await sut.execute(childID: toddler.id, on: today, photoMaxPixelSize: 600)
        let without = try await sut.execute(childID: toddler.id, on: today, photoMaxPixelSize: nil)

        #expect(withPhoto?.momentPhoto == Data("thumb600:jpeg".utf8))
        #expect(without?.momentPhoto == nil)
    }

    @Test("Given a moment whose photo is gone, when executing, then the moment is shown without a photo")
    func missingPhoto() async throws {
        try await onboard([toddler])
        try await progress.add(
            ProgressEvent(kind: .first(id: "f1"), childID: toddler.id, date: Self.date(2026, 6, 1), photoIDs: ["gone"])
        )

        let highlights = try await sut.execute(childID: toddler.id, on: today, photoMaxPixelSize: 600)

        #expect(highlights?.latestMoment?.first.id == "f1")
        #expect(highlights?.momentPhoto == nil)
    }

    @Test(
        "Given a phone on a lunar calendar, when picking the weekly quest, then it comes from the Gregorian age",
        arguments: [Calendar.Identifier.islamicUmmAlQura, .hebrew]
    )
    func weeklyQuestUsesTheGregorianAge(_ identifier: Calendar.Identifier) async throws {
        var phone = Calendar(identifier: identifier)
        phone.timeZone = Self.calendar.timeZone
        phone.firstWeekday = 2
        // 8 Gregorian months and 27 days on Monday 16 November: more than nine lunar months.
        try await onboard([Child(name: "Lena", birthDay: .day(2026, 2, 20))])
        let sut = DefaultGetWeeklyHighlightsUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: progress,
            photoStore: photos,
            calendar: phone
        )

        let highlights = try await sut.execute(childID: nil, on: today, photoMaxPixelSize: nil)

        guard case .suggested(let quest, _) = highlights?.quest else {
            Issue.record("Expected a quest")
            return
        }
        #expect(quest.id == "q1")
    }
}

@Suite("AppLink")
struct AppLinkTests {
    let child = UUID()

    @Test("Given each kind of link, when turned into a URL and back, then it is the same link")
    func roundTrip() {
        let links: [AppLink] = [
            .quest(id: "q-w0-first-aid", childID: child),
            .moment(eventID: UUID(), childID: child),
            .child(child)
        ]
        for link in links {
            #expect(AppLink(url: link.url) == link)
            #expect(link.childID == child)
        }
    }

    @Test("Given malformed URLs, when parsing, then none of them is a link")
    func rejectsMalformed() throws {
        let urls = [
            "https://quest/q1?child=\(child.uuidString)",
            "dadsaga://quest/q1",
            "dadsaga://quest/q1?child=not-a-uuid",
            "dadsaga://moment/not-a-uuid?child=\(child.uuidString)",
            "dadsaga://child/123",
            "dadsaga://boss/b1?child=\(child.uuidString)",
            "dadsaga://quest/a/b?child=\(child.uuidString)"
        ]
        for string in urls {
            let url = try #require(URL(string: string))
            #expect(AppLink(url: url) == nil, "\(string)")
        }
    }
}
