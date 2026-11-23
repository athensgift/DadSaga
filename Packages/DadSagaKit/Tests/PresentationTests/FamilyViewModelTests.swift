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
            bringBack: NoFamilyActs(),
            deleteForGood: NoFamilyActs(),
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
        let edit = await update.saved
        #expect(edit?.added.map(\.name) == ["Ελένη"])
        #expect(edit?.added.first?.gender == .girl)
        #expect(edit?.changed.isEmpty == true)
        #expect(edit?.removedIDs.isEmpty == true)
    }

    @Test("Given two children, when one is renamed and saved, then only that child's name is sent")
    func renameSendsOnlyTheName() async {
        let sut = makeSUT(profile: HeroStub.family)
        await sut.onAppear()

        sut.family.children[1].name = "Λένα"
        await sut.save()

        let edit = await update.saved
        #expect(edit?.changed.map(\.child.id) == [HeroStub.eleni.id])
        #expect(edit?.changed.first?.fields == [.name])
        #expect(edit?.added.isEmpty == true)
        #expect(edit?.hasPartner == nil)
    }

    @Test("Given two children, when one is removed and saved, then only its id is sent")
    func removalSendsOnlyTheID() async {
        let sut = makeSUT(profile: HeroStub.family)
        await sut.onAppear()

        sut.removeChild(id: HeroStub.eleni.id)
        await sut.save()

        #expect(await update.saved == FamilyEdit(removedIDs: [HeroStub.eleni.id]))
    }

    @Test("Given a saved rename, when a second save in the same visit changes the partner answer, then only that is sent")
    func secondSaveSendsOnlyWhatIsNew() async {
        let sut = makeSUT()
        await sut.onAppear()
        sut.family.children[0].name = "Νικόλας"
        await sut.save()

        sut.family.hasPartner.toggle()
        await sut.save()

        let edit = await update.saved
        #expect(edit?.changed.isEmpty == true)
        #expect(edit?.hasPartner != nil)
    }

    @Test("Given nothing changed, when saving, then an empty edit is sent and the screen closes")
    func unchangedSaveCloses() async {
        var closed = false
        let sut = makeSUT { closed = true }
        await sut.onAppear()

        await sut.save()

        #expect(await update.saved?.isEmpty == true)
        #expect(closed)
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

    @Test("Given a family saving, when the dad edits a name meanwhile, then that edit stays unsaved and the screen stays open")
    func editDuringASaveIsKept() async {
        var closed = false
        let sut = makeSUT { closed = true }
        await sut.onAppear()
        sut.family.children[0].name = "Νικόλας"
        await update.holdNext()
        let saving = Task { await sut.save() }
        while !sut.isSaving { await Task.yield() }

        sut.family.children[0].name = "Νικολάκης"
        await update.finishHeldSave()
        await saving.value

        #expect(await update.saved?.changed.map(\.child.name) == ["Νικόλας"])
        #expect(sut.hasUnsavedChanges)
        #expect(!closed)
    }

    @Test("Given a family whose save failed, when the dad tries again, then the old error goes while it saves")
    func retryClearsTheError() async {
        let sut = makeSUT()
        await sut.onAppear()
        sut.family.children[0].name = "Νικόλας"
        await update.failNext()
        await sut.save()
        #expect(sut.errorMessage != nil)

        await update.holdNext()
        let saving = Task { await sut.save() }
        while !sut.isSaving { await Task.yield() }

        #expect(sut.errorMessage == nil)
        await update.finishHeldSave()
        await saving.value
    }

    @Test("Given no profile, when appearing, then state is failed")
    func noProfile() async {
        let sut = makeSUT(profile: nil)
        await sut.onAppear()
        #expect(sut.state == .failed(message: "Δεν βρέθηκε προφίλ."))
    }
}

actor SpyUpdateFamily: UpdateFamilyUseCase {
    private(set) var saved: FamilyEdit?
    private var shouldFail = false

    func failNext() {
        shouldFail = true
    }

    private var holdsNext = false
    private var held: CheckedContinuation<Void, Never>?

    /// The next save waits until `finishHeldSave()`.
    func holdNext() {
        holdsNext = true
    }

    func finishHeldSave() {
        holdsNext = false
        held?.resume()
        held = nil
    }

    func execute(_ edit: FamilyEdit, on date: Date) async throws {
        if holdsNext { await withCheckedContinuation { held = $0 } }
        if shouldFail {
            shouldFail = false
            throw StubError.boom
        }
        saved = edit
    }
}
