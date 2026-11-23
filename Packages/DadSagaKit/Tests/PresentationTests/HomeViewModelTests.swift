import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile?, locale: String = "el_GR") -> HomeViewModel {
        makeHomeViewModel(profile: profile, progress: progress, locale: locale)
    }

    @Test("Given a quest card, when selecting and confirming it, then the card shows it, the title rises and the hero celebrates")
    func completesQuest() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        #expect(sut.selectedQuest?.title == "Αποστολή")
        #expect(sut.selectedQuest?.reward == "Φροντίδα")
        await sut.completeSelectedQuest()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(sut.selectedQuest == nil)
        #expect(content.dadTitle?.text == "Επίπεδο 1 · Νέος στο ταξίδι")
        #expect(content.cards.first { $0.id == "q1" }?.footnote == "Το έκανες 1 φορά")
        #expect(sut.celebration?.id == 1)
        #expect(sut.celebration?.skillText == "Η φροντίδα σου μεγάλωσε")
        #expect(sut.celebration?.highlight == .quest)

        // Care's mark rises as the badge goes, not with it (ADR-0059 §2).
        #expect(content.skills.marks.allSatisfy { $0.growth == 0 && $0.rises == 0 })

        sut.celebrationFinished(id: 1)
        #expect(sut.celebration == nil)
        guard case .loaded(let after) = sut.state else { Issue.record("Home isn't loaded"); return }
        #expect(after.skills.marks.map(\.rises) == [1, 0, 0, 0])
        #expect(after.skills.marks[0].growth > 0)
    }

    @Test("Given a quest done with a note, when opening it again, then the sheet shows what he wrote last time")
    func showsLastJournal() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        #expect(sut.selectedQuest?.lastJournal == nil)
        #expect(sut.selectedQuest?.journal.sectionTitle == "Σημείωση ή φωτογραφίες (προαιρετικά)")

        await sut.completeSelectedQuest(note: "το λάτρεψε")
        sut.select(cardID: "q1")

        #expect(sut.selectedQuest?.lastJournal?.note == "το λάτρεψε")
        #expect(sut.selectedQuest?.lastJournal?.title.hasSuffix("έγραψες:") == true)
    }

    @Test("Given a quest just completed, when undoing, then its XP is gone and the offer closes")
    func undoesCompletion() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        #expect(sut.undoOffer?.message == "Αποθηκεύτηκε")
        #expect(sut.undoOffer?.actionTitle == "Αναίρεση")

        await sut.undoLastRecord()

        #expect(sut.undoOffer == nil)
        #expect(sut.celebration == nil)
        #expect(await progress.eventCount == 0)
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        // Back to before the quest, the title it brought included (ADR-0055 §3).
        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
    }

    @Test("Given an undo offer, when an older offer expires, then the current one stays; when it expires, it closes")
    func undoExpires() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let offer = try #require(sut.undoOffer)

        sut.undoOfferExpired(id: offer.id - 1)
        #expect(sut.undoOffer == offer)
        sut.undoOfferExpired(id: offer.id)
        #expect(sut.undoOffer == nil)
        #expect(await progress.eventCount == 2)
    }

    @Test("Given no title yet, when the first quest brings one, then the hero carries its burp cloth and the card says so")
    func earnsGear() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        guard case .loaded(let before) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(before.heroGear.isEmpty)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.titleCard?.message == "Πήρες: Πανάκι.")
        #expect(sut.celebration?.highlight == .quest)
        guard case .loaded(let after) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(after.heroGear == [.burpCloth])
    }

    @Test("Given a defeated boss, when appearing, then the hero wears one medal")
    func medal() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.medalCount == 1)
    }

    @Test("Given a boss card, when selecting it, then its intro, guide and reward are shown")
    func bossDetail() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")

        #expect(sut.selectedQuest == nil)
        #expect(sut.selectedBoss?.title == "Αφεντικό")
        #expect(sut.selectedBoss?.intro == "ι")
        #expect(sut.selectedBoss?.guide == ["βήμα"])
        #expect(sut.selectedBoss?.reward == "β")
        #expect(sut.selectedBoss?.isDefeated == false)
    }

    @Test("Given a boss, when defeating it, then the skill and badge are celebrated and the card shows the badge")
    func defeatsBoss() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()

        #expect(sut.selectedBoss == nil)
        #expect(sut.celebration?.skillText == "Η φροντίδα σου μεγάλωσε")
        #expect(sut.celebration?.badgeText == "β")
        #expect(sut.celebration?.highlight == .boss)
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.cards.first { $0.id == "b1" }?.footnote == "Νικήθηκε · β")

        sut.select(cardID: "b1")
        #expect(sut.selectedBoss?.isDefeated == true)
    }

    @Test("Given saving fails, when confirming a quest, then the sheet stays open with an error")
    func completionFailure() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        await progress.failNext()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.selectedQuest != nil)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
        #expect(sut.celebration == nil)
    }

    @Test("Given a hero class the content no longer has, when appearing, then the dad is drawn as Super Dad")
    func removedHeroClass() async throws {
        let sut = makeSUT(profile: PlayerProfile(children: [HeroStub.niko], heroClassID: "h-gone"))
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else { throw StubLinkError.notLoaded }
        #expect(content.heroLook == .hero)
    }

    @Test("Given a cool dad with a 10-month-old, when appearing, then hero, companion and the world's cards show, bosses last")
    func loaded() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Cool Μπαμπάς")
        #expect(content.heroLook == .cool)
        #expect(content.companionLine == "Νίκος · 10 μηνών")
        #expect(content.dadTitle?.text == "Επίπεδο 0 · Σε αναμονή")
        #expect(content.worldTitle == "Κόσμος")
        #expect(content.cards.map(\.id) == ["q1", "b1"])
        #expect(content.cards.map(\.symbol) == ["heart.fill", "flame.fill"])
        #expect(content.cards.map(\.badge) == [nil, "BOSS"])
        #expect(content.cards.map(\.skill) == ["Φροντίδα", nil])
    }

    @Test("Given an English locale, when appearing, then the companion line is English")
    func english() async {
        let sut = makeSUT(profile: HeroStub.profile, locale: "en_US")
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroTitle == "Cool Dad")
        #expect(content.companionLine == "Νίκος · 10 months old")
    }

    @Test("Given one child, when appearing, then there is no child picker and the dad's skin tone is shown")
    func oneChild() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.childTabs.isEmpty)
        #expect(content.selectedChildLine == nil)
        #expect(content.selectedChildID == HeroStub.niko.id)
        #expect(content.heroSkin == .mediumDark)
        #expect(content.emptyMessage == nil)
        #expect(content.companions.map(\.name) == ["Νίκος"])
        #expect(content.companions.first?.stage == .baby)
        #expect(content.companions.first?.gender == .boy)
    }

    @Test("Given two children, when switching to the older one, then her line shows and there is nothing to play yet")
    func twoChildren() async {
        let sut = makeSUT(profile: HeroStub.family)
        await sut.onAppear()
        guard case .loaded(let first) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(first.companionLine == "Νίκος · Ελένη")
        #expect(first.childTabs.map(\.name) == ["Νίκος", "Ελένη"])
        #expect(first.selectedChildLine == "Νίκος · 10 μηνών")
        #expect(first.companions.map(\.id) == [HeroStub.niko.id, HeroStub.eleni.id])
        #expect(first.companions.last?.gender == .girl)

        await sut.selectChild(id: HeroStub.eleni.id)

        guard case .loaded(let second) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(second.selectedChildID == HeroStub.eleni.id)
        #expect(second.selectedChildLine == "Ελένη · 5 ετών")
        #expect(second.cards.isEmpty)
        #expect(second.emptyMessage == "Οι περιπέτειες για την ηλικία του παιδιού σου έρχονται σύντομα.")
    }

    @Test("Given the second child is selected, when completing a quest, then it is recorded with that child")
    func questWithSelectedChild() async {
        let older = Child(name: "Μαρία", birthDay: CalendarDay(HeroStub.today, in: .gmt))
        let sut = makeSUT(profile: PlayerProfile(children: [HeroStub.niko, older], heroClassID: "h-cool"))
        await sut.onAppear()
        await sut.selectChild(id: older.id)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(await progress.recordedChildIDs == [older.id])
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.cards.first { $0.id == "q1" }?.footnote == "Το έκανες 1 φορά")

        await sut.selectChild(id: HeroStub.niko.id)
        guard case .loaded(let niko) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(niko.cards.first { $0.id == "q1" }?.footnote == nil)
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}

extension HomeViewModelTests {
    @Test("Given another save still running, when undoing, then nothing is lost: the offer stays to tap again")
    func undoDuringSave() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()
        let offer = sut.undoOffer
        await progress.slowNext()
        sut.select(cardID: "q1")
        let saving = Task { await sut.completeSelectedQuest() }
        while !sut.isCompleting { await Task.yield() }

        await sut.undoLastRecord()

        #expect(sut.undoOffer == offer)
        await progress.finishSlowSave()
        await saving.value
        await sut.undoLastRecord()
        #expect(await progress.eventCount == 1)
    }
}

/// A home presenter wired to stubs, shared by the home suites.
@MainActor
func makeHomeViewModel(
    profile: PlayerProfile?,
    progress: FakeProgress,
    locale: String = "el_GR",
    reminder: ReminderUseCases = .neverOffered,
    film: FakeFilmOffers = FakeFilmOffers(),
    catalog: ContentCatalog = HeroStub.catalog
) -> HomeViewModel {
    HomeViewModel(
        useCases: HomeViewModel.UseCases(
            getOverview: FakeHomeOverview(profile: profile, catalog: catalog, progress: progress, film: film),
            completeQuest: progress,
            defeatBoss: progress,
            deleteEvent: progress,
            undoRecord: progress,
            moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
            reminder: reminder,
            answerSagaOffer: film,
            markTitleSeen: progress
        ),
        locale: Locale(identifier: locale),
        now: { HeroStub.today }
    )
}
