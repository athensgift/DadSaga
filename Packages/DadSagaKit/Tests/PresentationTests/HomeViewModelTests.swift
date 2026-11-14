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
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getProfile: StubGetProfile(profile: profile),
                loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
                getAdventure: StubGetAdventure(),
                getProgress: progress,
                completeQuest: progress,
                defeatBoss: progress,
                captureMoment: progress
            ),
            locale: Locale(identifier: locale),
            now: { HeroStub.today }
        )
    }

    @Test("Given a quest card, when selecting and confirming it, then XP is gained, the card shows it and the hero celebrates")
    func completesQuest() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        #expect(sut.selectedQuest?.title == "Αποστολή")
        #expect(sut.selectedQuest?.reward == "+20 XP · Φροντίδα")
        await sut.completeSelectedQuest()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(sut.selectedQuest == nil)
        #expect(content.xpLine == "20 / 100 XP")
        #expect(content.cards.last?.footnote == "Το έκανες 1 φορά")
        #expect(sut.celebration?.id == 1)
        #expect(sut.celebration?.xpText == "+20 XP")
        #expect(sut.celebration?.levelUpText == nil)

        sut.celebrationFinished()
        #expect(sut.celebration == nil)
    }

    @Test("Given 40 care XP, when a quest crosses 50, then the hero carries the burp cloth and the celebration says so")
    func earnsGear() async {
        await progress.seed(times: 2)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        guard case .loaded(let before) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(before.heroGear.isEmpty)

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.unlockText == "Νέο: Πανάκι")
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

    @Test("Given 80 XP, when completing a quest, then the celebration announces the new level")
    func levelUpCelebration() async {
        await progress.seed(times: 4)
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "q1")
        await sut.completeSelectedQuest()

        #expect(sut.celebration?.levelUpText == "Επίπεδο 2!")
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
        #expect(sut.selectedBoss?.reward == "+100 XP · β")
        #expect(sut.selectedBoss?.isDefeated == false)
    }

    @Test("Given a boss, when defeating it, then XP, badge and level-up are celebrated and the card shows the badge")
    func defeatsBoss() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.select(cardID: "b1")
        await sut.defeatSelectedBoss()

        #expect(sut.selectedBoss == nil)
        #expect(sut.celebration?.xpText == "+100 XP")
        #expect(sut.celebration?.badgeText == "β")
        #expect(sut.celebration?.levelUpText == "Επίπεδο 2!")
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.cards.first?.footnote == "Νικήθηκε · β")

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

    @Test("Given a cool dad with a 10-month-old, when appearing, then hero, companion and current-world cards are shown")
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
        #expect(content.level == 1)
        #expect(content.levelTitle == "Επίπεδο 1")
        #expect(content.xpLine == "0 / 100 XP")
        #expect(content.worldTitle == "Κόσμος")
        #expect(content.cards.map(\.id) == ["b1", "q1"])
        #expect(content.cards.map(\.symbol) == ["flame.fill", "heart.fill"])
        #expect(content.cards.last?.badge == "+20 XP")
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
        let older = Child(name: "Μαρία", birthDate: HeroStub.today)
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
        #expect(content.cards.last?.footnote == "Το έκανες 1 φορά")

        await sut.selectChild(id: HeroStub.niko.id)
        guard case .loaded(let niko) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(niko.cards.last?.footnote == nil)
    }

    @Test("Given no moments, when appearing, then the section is empty and counts all firsts")
    func emptyMoments() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.moments.title == "Θρυλικές στιγμές")
        #expect(content.moments.progress == "0 / 1")
        #expect(content.moments.cards.isEmpty)
        #expect(!content.moments.isComplete)
    }

    @Test("Given first steps, when capturing them, then a gold card shows, the child stands and the celebration says so")
    func capturesMoment() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.startCapture()
        #expect(sut.momentCapture?.options.map(\.title) == ["Βήματα"])
        #expect(sut.momentCapture?.title == "Νίκος")
        await sut.captureMoment(firstID: "f1", date: HeroStub.today, note: "Τρία βήματα!")

        #expect(sut.momentCapture == nil)
        #expect(sut.celebration?.momentText == "👣 Βήματα")
        #expect(sut.celebration?.xpText == "+30 XP")
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.moments.cards.map(\.title) == ["👣 Βήματα"])
        #expect(content.moments.cards.first?.subtitle.hasSuffix(" · Τρία βήματα!") == true)
        #expect(content.moments.isComplete)
        #expect(content.companions.first?.traits == [.walks])

        sut.startCapture()
        #expect(sut.momentCapture?.options.isEmpty == true)
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}
