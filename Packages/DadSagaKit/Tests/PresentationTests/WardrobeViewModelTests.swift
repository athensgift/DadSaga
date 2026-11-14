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
                getProfile: StubGetProfile(profile: HeroStub.profile),
                loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
                getProgress: progress,
                getOutfit: outfit,
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

    @Test("Given 60 care XP, when appearing, then the burp cloth is worn automatically and the next tier is locked")
    func loads() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()
        let content = try #require(loaded(sut))

        #expect(content.title == "Ντουλάπα")
        #expect(content.heroLook == .cool)
        #expect(content.heroSkin == .mediumDark)
        #expect(content.gear == [.burpCloth])
        #expect(content.slots.map(\.id) == ["care", "play", "patience", "resilience"])
        let care = try #require(content.slots.first)
        #expect(care.title == "Φροντίδα")
        #expect(care.xpText == "60 XP")
        #expect(care.options.map(\.title) == ["Αυτόματα", "Τίποτα", "Πανάκι", "x"])
        #expect(care.options.map(\.isSelected) == [true, false, false, false])
        #expect(care.options.map(\.isLocked) == [false, false, false, true])
        #expect(care.options.last?.detail == "Στα 200 XP")
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

    @Test("Given a locked item, when choosing it, then nothing changes")
    func lockedIgnored() async throws {
        await progress.seed(times: 3)
        let sut = makeSUT()
        await sut.onAppear()

        await sut.select(slotID: "care", optionID: "g2")

        #expect(await outfit.stored == Outfit())
        #expect(loaded(sut)?.slots.first?.options.first?.isSelected == true)
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
                getProfile: StubGetProfile(profile: HeroStub.profile),
                loadCatalog: StubLoadCatalog(result: .success(HeroStub.catalog)),
                getAdventure: StubGetAdventure(),
                getProgress: progress,
                completeQuest: progress,
                defeatBoss: progress,
                moments: HomeViewModel.MomentUseCases(capture: progress, update: progress, delete: progress, getPhoto: progress),
                getOutfit: outfit
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
        #expect(content.wardrobeTitle == "Ντουλάπα")
    }
}

actor FakeOutfit: GetOutfitUseCase, SetOutfitChoiceUseCase {
    private(set) var stored = Outfit()
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    func execute() async throws -> Outfit {
        stored
    }

    func execute(skill: Skill, choice: OutfitChoice) async throws -> Outfit {
        if shouldFail {
            shouldFail = false
            throw StubError.boom
        }
        stored.choices[skill] = choice == .automatic ? nil : choice
        return stored
    }
}
