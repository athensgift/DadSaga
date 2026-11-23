import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HeroSettingsViewModel")
struct HeroSettingsViewModelTests {
    let update = SpyUpdateHero()
    static let options: [DadAppearanceOption] = DadAppearance.Part.allCases.flatMap { part in
        DadAppearance.optionIDs(for: part).map { id in
            DadAppearanceOption(part: part, id: id, title: LocalizedText(el: "el-\(part.rawValue)-\(id)", en: id))
        }
    }

    func makeSUT(
        choice: HeroChoice? = HeroChoice(
            heroClasses: HeroStub.catalog.heroClasses,
            heroClassID: "h-cool",
            skinTone: .mediumDark,
            appearance: DadAppearance(hair: .curly, hairColor: .black, beard: .full, glasses: .none),
            appearanceOptions: options
        )
    ) -> HeroSettingsViewModel {
        HeroSettingsViewModel(
            getHeroChoice: StubGetHeroChoice(choice: choice),
            updateHero: update,
            locale: Locale(identifier: "el_GR")
        )
    }

    @Test("Given the Cool Dad with curly black hair, when appearing, then the hero, tone and look are shown in Greek")
    func loadsCurrentHero() async throws {
        let sut = makeSUT()

        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.title == "Ο ήρωάς σου")
        #expect(content.picker.heroes.map(\.title) == ["Σούπερ Μπαμπάς", "Cool Μπαμπάς"])
        #expect(sut.selectedHeroID == "h-cool")
        #expect(sut.previewLook == .cool)
        #expect(sut.skinTone == .mediumDark)
        #expect(sut.appearance.hair == .curly)
        let looks = try #require(sut.looks)
        #expect(looks.title == "Το στυλ σου")
        #expect(looks.rows.map(\.title) == ["Μαλλιά", "Χρώμα μαλλιών", "Γένια", "Γυαλιά"])
        #expect(looks.rows.map(\.selectedID) == ["curly", "black", "full", "none"])
        #expect(looks.rows[2].options.map(\.title) == ["el-beard-none", "el-beard-short", "el-beard-full"])
        #expect(await update.saves.isEmpty)
    }

    @Test("Given the Cool Dad, when choosing no beard, then only the beard is stored, at once, and the page shows it")
    func savesAtOnce() async {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.selectOption(rowID: "beard", optionID: "none")

        #expect(sut.appearance.beard == .none)
        #expect(sut.looks?.rows[2].selectedID == "none")
        #expect(await update.edits == [HeroEdit(beard: DadAppearance.Beard.none)])
        let saved = await update.saves.last
        #expect(saved?.heroClassID == "h-cool")
        #expect(saved?.skinTone == .mediumDark)
        #expect(saved?.appearance == DadAppearance(hair: .curly, hairColor: .black, beard: .none, glasses: .none))
    }

    @Test("Given the Cool Dad, when choosing his own hero again, then nothing is stored")
    func sameHeroStoresNothing() async {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.selectHero(id: "h-cool")

        #expect(await update.edits.isEmpty)
    }

    @Test("Given a slow first save, when choosing a hero, a tone and glasses quickly, then the store ends with all three")
    func quickChangesAllStored() async {
        let sut = makeSUT()
        await sut.onAppear()
        await update.delayNext()

        async let hero: Void = sut.selectHero(id: "h-super")
        async let tone: Void = sut.setSkinTone(.light)
        async let glasses: Void = sut.selectOption(rowID: "glasses", optionID: "round")
        _ = await (hero, tone, glasses)

        let last = await update.saves.last
        #expect(last?.heroClassID == "h-super")
        #expect(last?.skinTone == .light)
        #expect(last?.appearance.glasses == .round)
        #expect(sut.previewLook == .hero)
    }

    @Test("Given saving fails, when choosing short hair, then the page goes back to curly and says so")
    func saveFailureReverts() async {
        let sut = makeSUT()
        await sut.onAppear()
        await update.failNext()

        await sut.selectOption(rowID: "hair", optionID: "short")

        #expect(sut.appearance.hair == .curly)
        #expect(sut.looks?.rows[0].selectedID == "curly")
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }

    @Test("Given a slow save that fails while a newer change waits, when both finish, then the newer one stays, unannounced")
    func newerChangeSurvivesAFailedSave() async {
        let sut = makeSUT()
        await sut.onAppear()
        await update.delayNext()
        await update.failNext()

        async let first: Void = sut.selectOption(rowID: "hair", optionID: "short")
        async let second: Void = sut.selectOption(rowID: "beard", optionID: "none")
        _ = await (first, second)

        #expect(sut.errorMessage == nil)
        #expect(sut.appearance.hair == .short)
        #expect(sut.appearance.beard == .none)
        #expect(await update.saves.last?.appearance == DadAppearance(hair: .short, hairColor: .black, beard: .none))
        // The failed hair went again with the beard.
        #expect(await update.edits == [HeroEdit(hair: .short, beard: DadAppearance.Beard.none)])
    }

    @Test("Given black hair that came with the medium-dark tone, when choosing the light tone, then the hair turns brown")
    func standardHairFollowsTheTone() async {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.setSkinTone(.light)

        #expect(sut.appearance.hairColor == .brown)
        #expect(await update.edits == [HeroEdit(dadSkinTone: .light, hairColor: .brown)])
    }

    @Test("Given an option the app doesn't know, when choosing it, then nothing changes or is stored")
    func unknownOptionIgnored() async {
        let sut = makeSUT()
        await sut.onAppear()

        await sut.selectOption(rowID: "beard", optionID: "goatee")
        await sut.selectOption(rowID: "hat", optionID: "none")

        #expect(sut.appearance.beard == .full)
        #expect(await update.edits.isEmpty)
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(choice: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}

struct StubGetHeroChoice: GetHeroChoiceUseCase {
    let choice: HeroChoice?

    func execute() async throws -> HeroChoice? { choice }
}

/// Applies each edit to what it holds, which starts as `makeSUT`'s choice, so a test sees both what was sent and what the
/// store ends with.
actor SpyUpdateHero: UpdateHeroUseCase {
    struct Save { let heroClassID: String; let skinTone: SkinTone; let appearance: DadAppearance }
    private(set) var edits: [HeroEdit] = []
    private(set) var saves: [Save] = []
    private var held = PlayerProfile(
        id: UUID(), children: [], heroClassID: "h-cool", dadSkinTone: .mediumDark,
        dadAppearance: DadAppearance(hair: .curly, hairColor: .black, beard: .full, glasses: .none)
    )
    private var shouldFail = false
    private var shouldDelay = false

    func failNext() { shouldFail = true }
    func delayNext() { shouldDelay = true }

    func execute(_ edit: HeroEdit) async throws {
        if shouldDelay {
            shouldDelay = false
            try await Task.sleep(for: .milliseconds(100))
        }
        if shouldFail {
            shouldFail = false
            throw StubError.boom
        }
        edits.append(edit)
        held = edit.applied(to: held)
        saves.append(Save(heroClassID: held.heroClassID, skinTone: held.dadSkinTone, appearance: held.dadAppearance))
    }
}
