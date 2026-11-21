import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("FamilyViewModel")
struct FamilyViewModelTests {
    let update = SpyUpdateFamily()

    func makeSUT(profile: PlayerProfile? = HeroStub.profile, onSaved: @escaping @MainActor () -> Void = {}) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: StubGetProfile(profile: profile),
            updateFamily: update,
            locale: Locale(identifier: "el_GR"),
            now: HeroStub.today,
            onSaved: onSaved
        )
    }

    @Test("Given a stored family, when appearing, then the children are loaded in Greek")
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
    }

    @Test("Given a family, when adding a child and saving, then the children keep their ids and onSaved is called")
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
        let children = await update.saved
        #expect(children?.map(\.name) == ["Νίκος", "Ελένη"])
        #expect(children?.first?.id == HeroStub.niko.id)
        #expect(children?.last?.gender == .girl)
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
        await update.failNext()

        await sut.save()

        #expect(!saved)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }

    @Test("Given My family just opened, when nothing is touched, then leaving loses nothing")
    func openedFamilyHasNothingToLose() async {
        let sut = makeSUT()
        await sut.onAppear()

        #expect(!sut.hasUnsavedChanges)
    }

    @Test("Given My family open, when a name changes or a child is added, then leaving would lose it")
    func changedFamilyHasSomethingToLose() async {
        let sut = makeSUT()
        await sut.onAppear()

        sut.family.children[0].name = "Νικόλας"
        #expect(sut.hasUnsavedChanges)

        sut.family.children[0].name = "Νίκος"
        #expect(!sut.hasUnsavedChanges)

        sut.addChild()
        #expect(sut.hasUnsavedChanges)
    }

    @Test("Given a changed family, when saving fails, then the changes still count as unsaved; when it works, they don't")
    func savingSettlesTheChanges() async {
        let sut = makeSUT()
        await sut.onAppear()
        sut.family.children[0].name = "Νικόλας"
        await update.failNext()

        await sut.save()
        #expect(sut.hasUnsavedChanges)

        await sut.save()
        #expect(!sut.hasUnsavedChanges)
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}

actor SpyUpdateFamily: UpdateFamilyUseCase {
    private(set) var saved: [Child]?
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    func execute(children: [Child], on date: Date) async throws {
        if shouldFail {
            shouldFail = false
            throw StubError.boom
        }
        saved = children
    }
}
