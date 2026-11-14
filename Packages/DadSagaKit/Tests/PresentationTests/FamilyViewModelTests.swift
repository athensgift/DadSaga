import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("FamilyViewModel")
struct FamilyViewModelTests {
    let save = SpySaveProfile()

    func makeSUT(profile: PlayerProfile? = HeroStub.profile, onSaved: @escaping @MainActor () -> Void = {}) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: StubGetProfile(profile: profile),
            saveProfile: save,
            locale: Locale(identifier: "el_GR"),
            now: HeroStub.today,
            onSaved: onSaved
        )
    }

    @Test("Given a stored family, when appearing, then the children and skin tone are loaded in Greek")
    func loads() async {
        let sut = makeSUT()
        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.title == "Η οικογένειά μου")
        #expect(sut.family.children.map(\.name) == ["Νίκος"])
        #expect(sut.family.children.first?.id == HeroStub.niko.id)
        #expect(sut.family.dadSkinTone == .mediumDark)
    }

    @Test("Given a family, when adding a child and saving, then ids, hero and new child are saved and onSaved is called")
    func addsChild() async {
        var saved = false
        let sut = makeSUT { saved = true }
        await sut.onAppear()

        sut.addChild()
        #expect(!sut.canSave)
        sut.family.children[1].name = "Ελένη"
        sut.family.children[1].gender = .girl
        await sut.save()

        #expect(saved)
        let profile = await save.saved
        #expect(profile?.heroClassID == "h-cool")
        #expect(profile?.children.map(\.name) == ["Νίκος", "Ελένη"])
        #expect(profile?.children.first?.id == HeroStub.niko.id)
        #expect(profile?.children.last?.gender == .girl)
    }

    @Test("Given two children, when removing one, then the other stays and the last child cannot be removed")
    func removesChild() async {
        let sut = makeSUT(profile: HeroStub.family)
        await sut.onAppear()

        sut.removeChild(id: HeroStub.eleni.id)
        sut.removeChild(id: HeroStub.niko.id)

        #expect(sut.family.children.map(\.name) == ["Νίκος"])
    }

    @Test("Given saving fails, when saving, then an error is shown and onSaved is not called")
    func saveFailure() async {
        var saved = false
        let sut = makeSUT { saved = true }
        await sut.onAppear()
        await save.failNext()

        await sut.save()

        #expect(!saved)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}
