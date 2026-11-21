import Application
import Domain
import Foundation
import Testing

/// Home, the weekly quest and "My family" for a child not born yet, a dad without a partner and the bosses for when
/// life changes (ADR-0051).
@Suite("Use cases before birth and for each family")
struct BeforeBirthUseCaseTests {
    static let text = Stub.text
    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w0", order: 0, title: text, tagline: text, span: .beforeBirth),
            World(id: "w1", order: 1, title: text, tagline: text, span: .months(min: 0, max: nil))
        ],
        quests: [
            Quest(id: "q-w0-bag", worldID: "w0", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q-w0-talk", worldID: "w0", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                  onlyFor: [.partner]),
            Quest(id: "q-w1-feed", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q-w1-date", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                  onlyFor: [.partner]),
            Quest(id: "q-w1-tummy", worldID: "w1", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 0,
                  isRetired: true)
        ],
        bosses: [
            BossFight(id: "b-w0-birth", worldID: "w0", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0),
            BossFight(id: "b-w1-fever", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0),
            BossFight(id: "b-w1-move", worldID: "w1", title: text, intro: text, guide: [], badge: text,
                      skill: .resilience, xp: 100, minAgeMonths: 0, isSituational: true)
        ],
        firsts: []
    )

    let today = Date(timeIntervalSince1970: 1_795_000_000)
    let profiles = SpyProfileRepository()

    var home: DefaultGetHomeOverviewUseCase {
        DefaultGetHomeOverviewUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: SpyProgressRepository(),
            outfitRepository: SpyOutfitRepository(),
            sagaOfferRepository: FakeSagaOffers(),
            timeZone: .gmt
        )
    }

    var born: Child { Child(name: "Νίκος", birthDay: CalendarDay(today.addingTimeInterval(-30 * 86_400), in: .gmt)) }

    @Test("Given a child not born yet, when reading home, then World 0 and its cards show, and no situational row")
    func homeBeforeBirth() async throws {
        try await profiles.save(PlayerProfile(children: [Child(name: "Μπέμπης", birthDay: nil)], heroClassID: "h"))

        let overview = try #require(try await home.execute(childID: nil, worldID: nil, on: today))

        #expect(overview.adventure.age == .beforeBirth)
        #expect(overview.shownWorld?.id == "w0")
        #expect(overview.quests.map(\.id) == ["q-w0-bag", "q-w0-talk"])
        #expect(overview.bosses.map(\.id) == ["b-w0-birth"])
        #expect(overview.situationalBosses.isEmpty)
    }

    @Test("Given a dad without a partner, when reading home, then the partner cards are gone; the retired card never shows")
    func homeWithoutPartner() async throws {
        try await profiles.save(PlayerProfile(children: [born], heroClassID: "h", hasPartner: false))

        let overview = try #require(try await home.execute(childID: nil, worldID: nil, on: today))
        let harbour = try #require(try await home.execute(childID: nil, worldID: "w0", on: today))

        #expect(overview.quests.map(\.id) == ["q-w1-feed"])
        #expect(harbour.quests.map(\.id) == ["q-w0-bag"])
        #expect(!overview.family.hasPartner)
    }

    @Test("Given a situational boss, when reading home, then it is apart from the other bosses")
    func situationalApart() async throws {
        try await profiles.save(PlayerProfile(children: [born], heroClassID: "h"))

        let overview = try #require(try await home.execute(childID: nil, worldID: nil, on: today))

        #expect(overview.bosses.map(\.id) == ["b-w1-fever"])
        #expect(overview.situationalBosses.map(\.id) == ["b-w1-move"])
    }

    @Test("Given a child not born, or no partner, over a year of weekly quests, then World 0's, never a partner card")
    func weeklyQuest() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let sut = DefaultGetWeeklyHighlightsUseCase(
            contentRepository: StubContentRepository(result: .success(Self.catalog)),
            profileRepository: profiles,
            progressRepository: SpyProgressRepository(),
            photoStore: SpyPhotoStore(),
            calendar: calendar
        )
        try await profiles.save(PlayerProfile(children: [Child(name: "Μπέμπης", birthDay: nil)], heroClassID: "h"))
        for week in 0..<52 {
            let slot = try await sut.execute(childID: nil, on: today.addingTimeInterval(Double(week) * 7 * 86_400),
                                             photoMaxPixelSize: nil)?.quest
            guard case .suggested(let quest, _) = slot else { Issue.record("no quest"); return }
            #expect(quest.worldID == "w0")
        }

        try await profiles.save(PlayerProfile(children: [born], heroClassID: "h", hasPartner: false))
        for week in 0..<52 {
            let slot = try await sut.execute(childID: nil, on: today.addingTimeInterval(Double(week) * 7 * 86_400),
                                             photoMaxPixelSize: nil)?.quest
            guard case .suggested(let quest, _) = slot else { Issue.record("no quest"); return }
            #expect(quest.id == "q-w1-feed")
        }
    }

    @Test("Given a child not born yet, when saving a birth day and no partner, then the same child is born and the answer kept")
    func familyUpdate() async throws {
        let coming = Child(name: "Μπέμπης", birthDay: nil)
        try await profiles.save(PlayerProfile(children: [coming], heroClassID: "h"))
        var born = coming
        born.birthDay = CalendarDay(today, in: .gmt)

        try await DefaultUpdateFamilyUseCase(profileRepository: profiles, timeZone: .gmt)
            .execute(children: [born], hasPartner: false, on: today)

        let profile = try #require(try await profiles.fetchProfile())
        #expect(profile.children.map(\.id) == [coming.id])
        #expect(profile.children.first?.birthDay == CalendarDay(today, in: .gmt))
        #expect(!profile.hasPartner)
    }
}
