import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HeroSettingsViewModel")
struct HeroSettingsViewModelTests {
    let update = SpyUpdateHero()

    func makeSUT(
        choice: HeroChoice? = HeroChoice(heroClasses: HeroStub.catalog.heroClasses, heroClassID: "h-cool", skinTone: .mediumDark),
        onSaved: @escaping @MainActor () -> Void = {}
    ) -> HeroSettingsViewModel {
        HeroSettingsViewModel(
            getHeroChoice: StubGetHeroChoice(choice: choice),
            updateHero: update,
            locale: Locale(identifier: "el_GR"),
            now: HeroStub.today,
            onSaved: onSaved
        )
    }

    @Test("Given the Cool Dad with a medium-dark tone, when appearing, then both are selected and nothing can be saved yet")
    func loadsCurrentHero() async {
        let sut = makeSUT()

        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.title == "Ο ήρωάς σου")
        #expect(content.picker.heroes.map(\.title) == ["Σούπερ Μπαμπάς", "Cool Μπαμπάς"])
        #expect(sut.selectedHeroID == "h-cool")
        #expect(sut.skinTone == .mediumDark)
        #expect(!sut.canSave)
    }

    @Test("Given the current hero, when choosing Super Dad and a light tone and saving, then both are stored")
    func savesNewHero() async {
        var saved = false
        let sut = makeSUT { saved = true }
        await sut.onAppear()

        sut.selectHero(id: "h-super")
        sut.skinTone = .light
        #expect(sut.canSave)
        await sut.save()

        #expect(saved)
        #expect(await update.saved?.heroClassID == "h-super")
        #expect(await update.saved?.skinTone == .light)
    }

    @Test("Given saving fails, when saving, then an error shows and onSaved is not called")
    func saveFailure() async {
        var saved = false
        let sut = makeSUT { saved = true }
        await sut.onAppear()
        await update.failNext()

        sut.selectHero(id: "h-super")
        await sut.save()

        #expect(!saved)
        #expect(sut.errorMessage != nil)
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

actor SpyUpdateHero: UpdateHeroUseCase {
    private(set) var saved: (heroClassID: String, skinTone: SkinTone)?
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    func execute(heroClassID: String, skinTone: SkinTone, on date: Date) async throws {
        if shouldFail { throw StubError.boom }
        saved = (heroClassID, skinTone)
    }
}
