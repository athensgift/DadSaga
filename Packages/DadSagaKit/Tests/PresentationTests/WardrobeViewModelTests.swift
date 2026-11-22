import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("WardrobeViewModel")
struct WardrobeViewModelTests {
    let progress = FakeProgress()
    let outfit = FakeOutfit()

    func makeSUT(catalog: ContentCatalog = HeroStub.catalog) -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getWardrobe: FakeWardrobe(progress: progress, outfit: outfit, catalog: catalog),
                setChoice: outfit
            ),
            locale: Locale(identifier: "el_GR")
        )
    }

    func loaded(_ sut: WardrobeViewModel) -> WardrobeContent? {
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return nil
        }
        return content
    }

    @Test("Given the first title, when appearing, then the burp cloth it brought is worn, with no XP and nothing locked")
    func loads() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()
        let content = try #require(loaded(sut))

        #expect(content.title == "Ντουλάπα")
        #expect(content.heroLook == .cool)
        #expect(content.heroSkin == .mediumDark)
        #expect(content.heroAppearance.hairColor == .black)
        #expect(content.heroAppearance.beard == .full)
        #expect(content.gear == [.burpCloth])
        // Only slots the hero has something for; the next title's item isn't shown (ADR-0055 §8).
        #expect(content.slots.map(\.id) == ["care"])
        #expect(content.emptyMessage == nil)
        #expect(content.footnote == "Τα φέρνουν οι τίτλοι σου. Ό,τι έχεις μένει δικό σου.")
        let care = try #require(content.slots.first)
        #expect(care.title == "Φροντίδα")
        #expect(care.options.map(\.title) == ["Αυτόματα", "Τίποτα", "Πανάκι"])
        #expect(care.options.map(\.isSelected) == [true, false, false])
        #expect(care.options.map(\.item) == [nil, nil, .burpCloth])
    }

    @Test("Given nothing earned yet, when appearing, then one calm line shows and no slot")
    func emptyWardrobe() async throws {
        let sut = makeSUT()
        await sut.onAppear()
        let content = try #require(loaded(sut))

        #expect(content.slots.isEmpty)
        #expect(content.emptyMessage == "Ό,τι κερδίζει ο ήρωάς σου θα είναι εδώ.")
    }

    @Test("Given an earned item, when choosing nothing then the item, then the preview and storage follow")
    func chooses() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()

        await sut.select(slotID: "care", optionID: "hidden")
        #expect(loaded(sut)?.gear.isEmpty == true)
        #expect(await outfit.stored == Outfit(choices: [.care: .hidden]))

        await sut.select(slotID: "care", optionID: "g1")
        #expect(loaded(sut)?.gear == [.burpCloth])
        #expect(loaded(sut)?.slots.first?.options.map(\.isSelected) == [false, false, true])
        #expect(await outfit.stored == Outfit(choices: [.care: .item("g1")]))
    }

    @Test("Given the burp cloth was chosen under its former id, when the wardrobe opens, then it is worn and shown as chosen")
    func itemChosenUnderFormerIDIsChosen() async throws {
        await progress.seed(times: 3)
        await outfit.store(Outfit(choices: [.care: .item("g1-before")]))
        let sut = makeSUT()
        await sut.onAppear()
        let content = try #require(loaded(sut))

        #expect(content.gear == [.burpCloth])
        #expect(content.slots.first?.options.map(\.isSelected) == [false, false, true])
    }

    @Test("Given an item the next title brings, when choosing it anyway, then nothing changes")
    func lockedIgnored() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()

        await sut.select(slotID: "care", optionID: "g2")

        #expect(await outfit.stored == Outfit())
        #expect(loaded(sut)?.slots.first?.options.first?.isSelected == true)
    }

    @Test("Given a slow save for one slot, when another slot is chosen meanwhile, then both choices stay on screen")
    func overlappingTaps() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT(catalog: Self.withDuck)
        await sut.onAppear()
        await outfit.slowNext()

        let slow = Task { await sut.select(slotID: "care", optionID: "hidden") }
        await outfit.waitUntilSlowStarted()
        await sut.select(slotID: "play", optionID: "hidden")
        await slow.value

        let slots = try #require(loaded(sut)?.slots)
        #expect(slots.first { $0.id == "care" }?.options.map(\.isSelected).prefix(2) == [false, true])
        #expect(slots.first { $0.id == "play" }?.options.map(\.isSelected).prefix(2) == [false, true])
        #expect(await outfit.stored == Outfit(choices: [.care: .hidden, .play: .hidden]))
    }

    @Test("Given saving fails, when choosing, then the previous choice stays and an error shows")
    func saveFailure() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()
        await outfit.failNext()

        await sut.select(slotID: "care", optionID: "hidden")

        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
        #expect(loaded(sut)?.gear == [.burpCloth])
    }

    @Test("Given nothing is worn in a slot, when home appears, then the hero carries nothing there")
    func homeHonoursOutfit() async throws {
        await progress.seed(times: 3)
        _ = try await outfit.execute(skill: .care, choice: .hidden)
        let home = HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getOverview: FakeHomeOverview(profile: HeroStub.profile, progress: progress, outfit: outfit),
                completeQuest: progress,
                defeatBoss: progress,
                deleteEvent: progress,
                undoRecord: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
                reminder: .neverOffered,
                answerSagaOffer: FakeFilmOffers(),
                markTitleSeen: FakeTitleSeen()
            ),
            locale: Locale(identifier: "el_GR"),
            now: { HeroStub.today }
        )
        await home.onAppear()
        guard case .loaded(let content) = home.state else {
            Issue.record("Expected loaded state, got \(home.state)")
            return
        }
        #expect(content.heroGear.isEmpty)
    }
}

extension WardrobeViewModelTests {
    /// The hero stub's content, with a duck the first title also brings: two slots to choose in.
    static let withDuck: ContentCatalog = {
        let catalog = HeroStub.catalog
        let titles = catalog.titles.map { title in
            title.order == 1
                ? DadTitle(id: title.id, order: 1, minCards: title.minCards, minXP: title.minXP,
                           gearIDs: title.gearIDs + ["g-duck"], name: title.name)
                : title
        }
        return ContentCatalog(
            worlds: catalog.worlds, quests: catalog.quests, bosses: catalog.bosses, firsts: catalog.firsts,
            heroClasses: catalog.heroClasses,
            gear: catalog.gear + [GearItem(id: "g-duck", skill: .play, look: "duck", title: HeroStub.text)],
            titles: titles
        )
    }()
}

/// The hero stub's wardrobe, read from the fake log and the fake outfit.
struct FakeWardrobe: GetWardrobeUseCase {
    let progress: FakeProgress
    let outfit: FakeOutfit
    var catalog = HeroStub.catalog

    func execute() async throws -> Wardrobe {
        let progress = DadProgress(events: await self.progress.events, catalog: catalog)
        return Wardrobe(
            profile: HeroStub.profile,
            hero: catalog.heroClasses.first { $0.id == HeroStub.profile.heroClassID },
            earned: DadStanding(progress: progress, catalog: catalog, kept: await self.progress.kept).gear,
            progress: progress,
            outfit: await outfit.stored
        )
    }
}

actor FakeOutfit: SetOutfitChoiceUseCase {
    private(set) var stored = Outfit()
    private var shouldFail = false

    private var isSlow = false
    private var slowStarted = false

    func failNext() {
        shouldFail = true
    }

    func store(_ outfit: Outfit) {
        stored = outfit
    }

    /// The next save is stored at once but its reply comes late, after any save made meanwhile: the reply's outfit
    /// does not have that later change.
    func slowNext() {
        isSlow = true
    }

    func waitUntilSlowStarted() async {
        while !slowStarted { await Task.yield() }
    }

    func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit {
        if isSlow {
            isSlow = false
            stored.choices[skill] = choice == .automatic ? nil : choice
            let reply = stored
            slowStarted = true
            try? await Task.sleep(for: .milliseconds(200))
            return reply
        }
        if shouldFail {
            shouldFail = false
            throw StubError.boom
        }
        stored.choices[skill] = choice == .automatic ? nil : choice
        return stored
    }
}
