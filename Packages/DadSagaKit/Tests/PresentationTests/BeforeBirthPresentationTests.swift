import Application
import Domain
import Foundation
import Presentation
import Testing

/// Content with a world before birth, for the screens of ADR-0053.
enum HarbourStub {
    static let text = LocalizedText(el: "x", en: "x")
    static func named(_ el: String, _ en: String) -> LocalizedText { LocalizedText(el: el, en: en) }

    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w0", order: 0, title: named("Λιμάνι", "Harbour"), tagline: text, span: .beforeBirth),
            World(id: "w1", order: 1, title: named("Βάλτος", "Swamp"), tagline: text, span: .months(min: 0, max: 8)),
            World(id: "w2", order: 2, title: named("Πεδιάδα", "Plains"), tagline: text, span: .months(min: 9, max: nil))
        ],
        quests: [
            Quest(id: "q-w0-bag", worldID: "w0", title: named("Τσάντα", "Bag"), description: text, skill: .care, xp: 20,
                  minAgeMonths: 0),
            Quest(id: "q-w0-talk", worldID: "w0", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                  onlyFor: [.partner]),
            Quest(id: "q-w1-feed", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0),
            Quest(id: "q-w1-date", worldID: "w1", title: text, description: text, skill: .care, xp: 20, minAgeMonths: 0,
                  onlyFor: [.partner]),
            Quest(id: "q-w1-tummy", worldID: "w1", title: text, description: text, skill: .play, xp: 20, minAgeMonths: 0,
                  isRetired: true)
        ],
        bosses: [
            BossFight(id: "b-w0-birth", worldID: "w0", title: text, intro: text, guide: [text], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0),
            BossFight(id: "b-w1-fever", worldID: "w1", title: text, intro: text, guide: [text], badge: text,
                      skill: .care, xp: 100, minAgeMonths: 0),
            BossFight(id: "b-w1-double", worldID: "w1", title: text, intro: text, guide: [text],
                      badge: named("Διπλή βάρδια", "Double shift"), skill: .care, xp: 100, minAgeMonths: 0,
                      isEvergreen: true),
            BossFight(id: "b-w1-move", worldID: "w1", title: named("Μετακόμιση", "The move"), intro: text, guide: [text],
                      badge: text, skill: .resilience, xp: 100, minAgeMonths: 0, isSituational: true)
        ],
        firsts: [
            FirstMoment(id: "f-found-out", order: 1, emoji: "💛", title: text, xp: 30, companionTrait: nil,
                        isBeforeBirth: true),
            FirstMoment(id: "f-picture", order: 2, emoji: "🖼️", title: text, xp: 30, companionTrait: nil,
                        isBeforeBirth: true),
            FirstMoment(id: "f-smile", order: 3, emoji: "😊", title: text, xp: 30, companionTrait: nil),
            FirstMoment(id: "f-sleepover", order: 4, emoji: "🏕️", title: text, xp: 30, companionTrait: nil,
                        isRetired: true)
        ],
        heroClasses: HeroStub.catalog.heroClasses
    )

    static let today = HeroStub.today
    static let unborn = Child(name: "Μπέμπης", birthDay: nil)
    static let born = Child(name: "Νίκος", birthDay: CalendarDay(today, in: .gmt).adding(months: -2))
}

/// Home's overview with the real rules over `HarbourStub.catalog`.
struct HarbourOverview: GetHomeOverviewUseCase {
    let profile: PlayerProfile
    var events: [ProgressEvent] = []

    func execute(childID: UUID?, worldID: String?, on date: Date) async throws -> HomeOverview? {
        guard let child = profile.child(childID) else { return nil }
        let catalog = HarbourStub.catalog
        let today = CalendarDay(date, in: .gmt)
        return HomeOverview(
            profile: profile,
            child: child,
            catalog: catalog,
            adventure: Adventure(for: child, family: FamilyFacts(profile: profile, child: child), catalog: catalog, on: today),
            progress: DadProgress(events: events, catalog: catalog),
            kept: .fresh,
            outfit: Outfit(),
            worldID: worldID,
            today: today
        )
    }
}

@MainActor
@Suite("Screens before birth and for each family")
struct BeforeBirthPresentationTests {
    let progress = FakeProgress()

    func home(_ profile: PlayerProfile, events: [ProgressEvent] = [], locale: String = "el_GR") -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: HarbourOverview(profile: profile, events: events),
                completeQuest: progress,
                defeatBoss: progress,
                deleteEvent: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
                reminder: .neverOffered,
                answerSagaOffer: FakeFilmOffers(),
                markTitleSeen: FakeTitleSeen()
            ),
            locale: Locale(identifier: locale),
            timeZone: .gmt,
            now: { HarbourStub.today }
        )
    }

    func content(_ sut: HomeViewModel) throws -> HomeContent {
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        return content
    }

    func profile(_ children: [Child], partner: Bool = true) -> PlayerProfile {
        PlayerProfile(children: children, heroClassID: "h-cool", hasPartner: partner)
    }

    // MARK: Home

    @Test("Given a child not born yet, when home loads, then it reads on the way, with the mark, World 0 and the arrival line")
    func homeBeforeBirth() async throws {
        let sut = home(profile([HarbourStub.unborn]))
        await sut.onAppear()
        let content = try content(sut)

        #expect(content.companionLine == "Μπέμπης · έρχεται")
        #expect(content.heroTagline == nil)
        #expect(content.companions.first?.stage == .onTheWay)
        #expect(content.companions.first?.spokenName == "Μπέμπης, έρχεται")
        #expect(content.worldTitle == "Λιμάνι")
        #expect(content.arrivalLine == "Όταν έρθει, κλείσε το «Δεν έχει γεννηθεί ακόμα» στο «Η οικογένειά μου».")
        #expect(content.cards.map(\.id) == ["b-w0-birth", "q-w0-bag", "q-w0-talk"])
        #expect(content.situational == nil)
        #expect(content.emptyMessage == nil)
    }

    @Test("Given a born child, when home loads, then the situational boss waits in its own row, and no arrival line")
    func situationalRow() async throws {
        let sut = home(profile([HarbourStub.born]), locale: "en_US")
        await sut.onAppear()
        let content = try content(sut)

        #expect(content.arrivalLine == nil)
        #expect(content.heroTagline != nil)
        #expect(content.cards.map(\.id) == ["b-w1-fever", "b-w1-double", "q-w1-feed", "q-w1-date"])
        #expect(content.situational?.title == "When life changes")
        #expect(content.situational?.cards.map(\.id) == ["b-w1-move"])

        sut.select(cardID: "b-w1-move")
        #expect(sut.selectedBoss?.id == "b-w1-move")
    }

    @Test("Given the open row, when home reloads after a save, then it stays; opened again, another world or child, it closes")
    func situationalRowStaysOpenThroughASave() async throws {
        let second = Child(name: "Ελένη", birthDay: CalendarDay(HarbourStub.today, in: .gmt).adding(months: -1))
        let sut = home(profile([HarbourStub.born, second]))
        let rowID = { try self.content(sut).situational?.id }
        await sut.onAppear()
        let opened = try rowID()

        await sut.reload()
        await sut.appBecameActive()
        #expect(try rowID() == opened, "a save or coming back reloads home without closing the row")

        await sut.onAppear()
        let reopened = try rowID()
        #expect(reopened != opened)

        await sut.showWorld(id: "w0")
        await sut.showWorld(id: nil)
        let back = try rowID()
        #expect(back != reopened)

        await sut.selectChild(id: second.id)
        #expect(try rowID() != back)
    }

    @Test("Given a dad without a partner, when home loads, then the partner cards are not there")
    func noPartner() async throws {
        let sut = home(profile([HarbourStub.born], partner: false))
        await sut.onAppear()

        #expect(try content(sut).cards.map(\.id) == ["b-w1-fever", "b-w1-double", "q-w1-feed"])
    }

    @Test("Given an evergreen boss beaten in its own world, when home shows a later world, then it reads Defeated there")
    func evergreenBossDefeatedLater() async throws {
        let older = Child(name: "Ελένη", birthDay: CalendarDay(HarbourStub.today, in: .gmt).adding(months: -10))
        let beaten = ProgressEvent(
            kind: .boss(id: "b-w1-double"), childID: older.id, date: HarbourStub.today.addingTimeInterval(-90 * 86_400)
        )
        let sut = home(profile([older]), events: [beaten])
        await sut.onAppear()
        let content = try content(sut)

        #expect(content.worldTitle == "Πεδιάδα")
        let card = try #require(content.cards.first { $0.id == "b-w1-double" })
        #expect(card.footnote == "Νικήθηκε · Διπλή βάρδια")
    }

    // MARK: The map

    @Test("Given a child not born yet, when opening the map, then World 0 is current and the rest open after the birth")
    func mapBeforeBirth() async throws {
        let sut = home(profile([HarbourStub.unborn]))
        await sut.onAppear()
        sut.openMap()
        let map = try #require(sut.worldMap)

        #expect(map.subtitle == "Μπέμπης · έρχεται")
        #expect(map.worlds.map(\.status) == [WorldMapItem.Status.current, .locked, .locked])
        #expect(map.worlds.map(\.ageRange) == ["πριν τη γέννα", "0–8 μηνών", "από 0½ ετών"])
        #expect(map.worlds.dropFirst().map(\.detail) == ["Ανοίγει μετά τη γέννα", "Ανοίγει μετά τη γέννα"])
    }

    @Test("Given a born child, when opening the map, then World 0 is a visited world that counts what was done in it")
    func mapAfterBirth() async throws {
        let done = ProgressEvent(kind: .quest(id: "q-w0-bag"), childID: HarbourStub.born.id, date: HarbourStub.today)
        let sut = home(profile([HarbourStub.born]), events: [done])
        await sut.onAppear()
        sut.openMap()
        let map = try #require(sut.worldMap)

        #expect(map.worlds.map(\.status) == [WorldMapItem.Status.visited, .current, .locked])
        #expect(map.worlds[0].detail == "1 αποστολή · 0 αφεντικά")
        #expect(map.worlds[2].detail == "Ξεκλειδώνει σε 7 μήνες")
    }

    // MARK: Moments

    @Test("Given a child not born yet, when capturing a moment, then only the two firsts before birth, datable any day")
    func momentsBeforeBirth() async throws {
        let sut = home(profile([HarbourStub.unborn]))
        await sut.onAppear()
        #expect(try content(sut).moments.emptyText == "Η μέρα που το έμαθες, η πρώτη εικόνα… Κράτα τες εδώ.")

        sut.startCapture()
        guard case .choose(let choice) = sut.momentCapture?.step else { throw StubError.boom }
        #expect(choice.options.map(\.id) == ["f-found-out", "f-picture"])
        #expect(choice.options.allSatisfy { $0.earliestDate == .distantPast })
        #expect(choice.earliestDate == .distantPast)
    }

    @Test("Given the retired first captured, when capturing, then it isn't offered, its card shows")
    func retiredFirst() async throws {
        let child = HarbourStub.born
        let events = ["f-sleepover", "f-found-out", "f-picture"].map {
            ProgressEvent(kind: .first(id: $0), childID: child.id, date: HarbourStub.today)
        }
        let sut = home(profile([child]), events: events)
        await sut.onAppear()
        let moments = try content(sut).moments
        #expect(moments.cards.count == 3)
        #expect(!moments.isComplete)

        sut.startCapture()
        guard case .choose(let choice) = sut.momentCapture?.step else { throw StubError.boom }
        #expect(choice.options.map(\.id) == ["f-smile"])
        #expect(choice.options.first?.earliestDate == child.birthDay?.start(in: .gmt))

        let all = events + [ProgressEvent(kind: .first(id: "f-smile"), childID: child.id, date: HarbourStub.today)]
        let complete = home(profile([child]), events: all)
        await complete.onAppear()
        #expect(try content(complete).moments.isComplete)
    }

    // MARK: Links

    @Test("Given a link to a retired quest or to a card for someone else, when opening it, then no sheet opens")
    func linksOpenOnlyOfferedCards() async throws {
        let child = HarbourStub.born
        let sut = home(profile([child], partner: false))
        await sut.onAppear()

        await sut.open(.quest(id: "q-w1-tummy", childID: child.id))
        #expect(sut.selectedQuest == nil)
        await sut.open(.quest(id: "q-w1-date", childID: child.id))
        #expect(sut.selectedQuest == nil)
        await sut.open(.quest(id: "q-w1-feed", childID: child.id))
        #expect(sut.selectedQuest?.id == "q-w1-feed")
    }

    // MARK: Onboarding and My family

    @Test("Given onboarding, when ticking not born and turning the partner off, then the profile has no day and no partner")
    func onboarding() async throws {
        let save = SpySaveProfile()
        let sut = OnboardingViewModel(
            loadCatalog: StubLoadCatalog(result: .success(HarbourStub.catalog)),
            saveProfile: save,
            locale: Locale(identifier: "el_GR"),
            now: HarbourStub.today,
            timeZone: .gmt,
            onFinished: {}
        )
        await sut.onAppear()
        guard case .loaded(let content) = sut.state else { throw StubError.boom }
        #expect(content.childEditor.notBornLabel == "Δεν έχει γεννηθεί ακόμα")
        #expect(content.childEditor.unbornNamePlaceholder == "Όνομα ή χαϊδευτικό")
        #expect(content.partner.title == "Έχω σύντροφο")
        #expect(content.partner.line == "Δείχνει τις κάρτες για τους δυο σας.")
        #expect(sut.family.hasPartner)

        sut.family.children[0].name = "Μπέμπης"
        sut.family.children[0].isBorn = false
        sut.family.hasPartner = false
        sut.continueToHero()
        sut.selectHero(id: "h-cool")
        await sut.finish()

        let saved = try #require(await save.saved)
        #expect(saved.children.first?.birthDay == nil)
        #expect(!saved.hasPartner)
    }

    @Test("Given My family, when unticking not born and saving, then the same child is born today; either switch is unsaved")
    func familyBirth() async throws {
        let update = SpyUpdateFamily()
        let sut = FamilyViewModel(
            getProfile: StubGetProfile(profile: profile([HarbourStub.unborn])),
            updateFamily: update,
            locale: Locale(identifier: "el_GR"),
            now: HarbourStub.today,
            timeZone: .gmt,
            onSaved: {}
        )
        await sut.onAppear()
        #expect(sut.family.children[0].isBorn == false)
        #expect(sut.family.children[0].birthDay == CalendarDay(HarbourStub.today, in: .gmt))
        #expect(!sut.hasUnsavedChanges)

        sut.family.hasPartner = false
        #expect(sut.hasUnsavedChanges)
        sut.family.hasPartner = true
        sut.family.children[0].isBorn = true
        #expect(sut.hasUnsavedChanges)
        await sut.save()

        let saved = try #require(await update.saved)
        #expect(saved.map(\.id) == [HarbourStub.unborn.id])
        #expect(saved.first?.birthDay == CalendarDay(HarbourStub.today, in: .gmt))
        #expect(await update.savedHasPartner == true)
        #expect(!sut.hasUnsavedChanges)
    }
}
