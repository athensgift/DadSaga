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

    func makeSUT() -> WardrobeViewModel {
        WardrobeViewModel(
            useCases: WardrobeViewModel.UseCases(
                getWardrobe: FakeWardrobe(progress: progress, outfit: outfit),
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

    @Test("Given 60 care XP, when appearing, then the burp cloth is worn automatically and the next tier shows the XP towards it")
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
        #expect(content.slots.map(\.id) == ["care", "play", "patience", "resilience"])
        let care = try #require(content.slots.first)
        #expect(care.title == "Φροντίδα")
        #expect(care.xpText == "60 XP")
        #expect(care.options.map(\.title) == ["Αυτόματα", "Τίποτα", "Πανάκι", "x"])
        #expect(care.options.map(\.isSelected) == [true, false, false, false])
        #expect(care.options.map(\.isLocked) == [false, false, false, true])
        #expect(care.options.last?.detail == "60 / 200 XP")
        #expect(care.options.last?.progress == 0.3)
        #expect(care.options.dropLast().allSatisfy { $0.progress == nil })
        // Real items carry their drawing for the wardrobe icon; a look the app cannot draw carries none.
        #expect(care.options.map(\.item) == [nil, nil, .burpCloth, nil])
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
        #expect(loaded(sut)?.slots.first?.options.map(\.isSelected) == [false, false, true, false])
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
        #expect(content.slots.first?.options.map(\.isSelected) == [false, false, true, false])
    }

    @Test("Given a locked item, when choosing it, then nothing changes")
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
        let sut = makeSUT()
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
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, getPhoto: progress),
                reminder: .neverOffered,
                answerSagaOffer: FakeFilmOffers()
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

/// The hero stub's wardrobe, read from the fake log and the fake outfit.
struct FakeWardrobe: GetWardrobeUseCase {
    let progress: FakeProgress
    let outfit: FakeOutfit

    func execute() async throws -> Wardrobe {
        Wardrobe(
            profile: HeroStub.profile,
            hero: HeroStub.catalog.heroClasses.first { $0.id == HeroStub.profile.heroClassID },
            gear: HeroStub.catalog.gear,
            progress: await progress.current,
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
