import Application
import Domain
import Foundation
import Presentation
import Testing

/// "My family"'s removed children: listed by name, brought back or deleted for good at once, after a calm question
/// that shows no counts (ADR-0065 §4).
@MainActor
@Suite("FamilyViewModel: removed children")
struct FamilyRemovedChildrenTests {
    let lena = Child(name: "Λένα", birthDay: nil)
    let iris = Child(name: "Ίρις", birthDay: nil)
    let nikos = Child(name: "Νίκος", birthDay: nil)
    let update = SpyUpdateFamily()

    func makeSUT(
        _ family: FakeFamily, locale: String = "el_GR", saves: (any UpdateFamilyUseCase)? = nil
    ) -> FamilyViewModel {
        FamilyViewModel(
            getProfile: family, updateFamily: saves ?? update, bringBack: FakeBringBack(family: family),
            deleteForGood: FakeDeleteForGood(family: family),
            locale: Locale(identifier: locale), now: { HeroStub.today }, timeZone: .gmt, onSaved: {}
        )
    }

    /// Λένα, then Ίρις removed, then Νίκος: the order the dad entered them.
    func family() -> FakeFamily {
        FakeFamily(children: [(lena, false), (iris, true), (nikos, false)])
    }

    @Test("Given a removed child, when My family opens, then they are listed by name, apart from the family")
    func listsRemovedChildren() async {
        let sut = makeSUT(family())
        await sut.onAppear()

        #expect(sut.removedChildren.map(\.name) == ["Ίρις"])
        #expect(sut.family.children.map(\.name) == ["Λένα", "Νίκος"])
        #expect(sut.canBringBack)
    }

    @Test("Given no removed child, when My family opens, then nothing is listed")
    func noneListed() async {
        let sut = makeSUT(FakeFamily(children: [(lena, false)]))
        await sut.onAppear()

        #expect(sut.removedChildren.isEmpty)
    }

    @Test("Given a removed child, when brought back, then they are in their place and nothing is left unsaved")
    func bringsBackInPlace() async {
        let sut = makeSUT(family())
        await sut.onAppear()

        await sut.bringBack(id: iris.id)

        #expect(sut.family.children.map(\.name) == ["Λένα", "Ίρις", "Νίκος"])
        #expect(sut.removedChildren.isEmpty)
        #expect(!sut.hasUnsavedChanges)
    }

    @Test("Given an unsaved rename, when a child is brought back, then the rename stays unsaved and Save sends only it")
    func unsavedRenameSurvives() async {
        let sut = makeSUT(family())
        await sut.onAppear()
        sut.family.children[1].name = "Νικόλας"

        await sut.bringBack(id: iris.id)

        #expect(sut.family.children.map(\.name) == ["Λένα", "Ίρις", "Νικόλας"])
        #expect(sut.hasUnsavedChanges)
        await sut.save()
        let edit = await update.saved
        #expect(edit?.changed.map(\.child.id) == [nikos.id])
        #expect(edit?.changed.first?.fields == [.name])
        #expect(edit?.added.isEmpty == true)
        #expect(edit?.removedIDs.isEmpty == true)
    }

    @Test("Given four in the family, when My family opens, then a removed child can't be brought back and a line says why")
    func fullFamily() async {
        let four = (1...4).map { number in (Child(name: "Παιδί \(number)", birthDay: nil), false) }
        let sut = makeSUT(FakeFamily(children: four + [(iris, true)]))
        await sut.onAppear()

        #expect(sut.isFamilyFull)
        #expect(!sut.canBringBack)
        await sut.bringBack(id: iris.id)
        #expect(sut.removedChildren.map(\.id) == [iris.id])
    }

    @Test(
        "Given a removed child, when asked to delete them for good, then the question names them and shows no counts",
        arguments: ["el_GR", "en_US"]
    )
    func calmQuestion(locale: String) async throws {
        let sut = makeSUT(family(), locale: locale)
        await sut.onAppear()

        sut.requestDeletion(id: iris.id)

        let prompt = try #require(sut.deletion)
        #expect(prompt.id == iris.id)
        #expect(prompt.message.contains("Ίρις"))
        for text in [prompt.title, prompt.message, prompt.confirmTitle] {
            let hasDigit = text.contains { $0.isNumber }
            #expect(!hasDigit)
            #expect(!text.isEmpty)
        }
    }

    @Test("Given the question, when cancelled, then nothing is deleted; when confirmed, then the child is gone")
    func confirmsDeletion() async {
        let family = family()
        let sut = makeSUT(family)
        await sut.onAppear()

        sut.requestDeletion(id: iris.id)
        sut.cancelDeletion()
        #expect(sut.deletion == nil)
        #expect(sut.removedChildren.map(\.id) == [iris.id])

        sut.requestDeletion(id: iris.id)
        await sut.confirmDeletion(id: iris.id)

        #expect(sut.removedChildren.isEmpty)
        #expect(sut.family.children.map(\.name) == ["Λένα", "Νίκος"])
        #expect(await family.deletedForGood == [iris.id])
    }

    @Test("Given the store fails, when bringing back or deleting for good, then an error shows and nothing changes")
    func failedActs() async {
        let family = family()
        let sut = makeSUT(family)
        await sut.onAppear()
        await family.fail()

        await sut.bringBack(id: iris.id)
        #expect(sut.errorMessage != nil)
        await sut.confirmDeletion(id: iris.id)

        #expect(sut.errorMessage != nil)
        #expect(sut.removedChildren.map(\.id) == [iris.id])
        #expect(sut.family.children.map(\.name) == ["Λένα", "Νίκος"])
        #expect(!sut.isSaving)
    }

    @Test("Given four stored and one removed in the draft, unsaved, when My family shows, then a child can't be brought back yet")
    func fullUntilSaved() async {
        let four = (1...4).map { number in (Child(name: "Παιδί \(number)", birthDay: nil), false) }
        let sut = makeSUT(FakeFamily(children: four + [(iris, true)]))
        await sut.onAppear()

        sut.removeChild(id: sut.family.children[0].id)

        #expect(sut.family.canAddChild)
        #expect(sut.isFamilyFull)
        #expect(!sut.canBringBack)
    }

    @Test("Given a removal, an added child and the partner switch unsaved, when a child is brought back, then all stay pending")
    func pendingEditsSurvive() async {
        let sut = makeSUT(family())
        await sut.onAppear()
        sut.removeChild(id: lena.id)
        sut.addChild()
        sut.family.children[1].name = "Άρης"
        sut.family.hasPartner = false

        await sut.bringBack(id: iris.id)

        #expect(sut.family.children.map(\.name) == ["Ίρις", "Νίκος", "Άρης"])
        #expect(!sut.family.hasPartner)
        await sut.save()
        let edit = await update.saved
        #expect(edit?.removedIDs == [lena.id])
        #expect(edit?.added.map(\.name) == ["Άρης"])
        #expect(edit?.hasPartner == false)
        #expect(edit?.changed.isEmpty == true)
    }

    @Test("Given an act under way, when Save, the other act or the question is tried, then each waits for it")
    func oneActAtATime() async {
        let family = family()
        let sut = makeSUT(family)
        await sut.onAppear()
        sut.family.children[0].name = "Λενιώ"
        await family.holdNext()
        let bringing = Task { await sut.bringBack(id: iris.id) }
        while !sut.isSaving { await Task.yield() }

        #expect(!sut.canSave)
        #expect(!sut.canBringBack)
        sut.requestDeletion(id: iris.id)
        #expect(sut.deletion == nil)
        await sut.confirmDeletion(id: iris.id)
        await family.release()
        await bringing.value

        #expect(await family.deletedForGood.isEmpty)
        #expect(sut.family.children.map(\.name) == ["Λενιώ", "Ίρις", "Νίκος"])
    }

    @Test("Given a delete for good that succeeds, when the family can't be read again, then the row goes and the error says so")
    func failedReadAfterAnAct() async {
        let family = family()
        let sut = makeSUT(family)
        await sut.onAppear()
        await family.failReading()

        await sut.confirmDeletion(id: iris.id)

        #expect(await family.deletedForGood == [iris.id])
        #expect(sut.removedChildren.isEmpty)
        #expect(sut.errorMessage == "Η οικογένεια δεν φόρτωσε.")
    }

    @Test("Given a removal saved while the dad keeps editing, when the save ends, then the page lists the child as removed")
    func saveListsTheRemovedChild() async {
        let family = family()
        let sut = makeSUT(family, saves: family)
        await sut.onAppear()
        sut.removeChild(id: nikos.id)
        await family.holdNext()
        let saving = Task { await sut.save() }
        while !sut.isSaving { await Task.yield() }

        sut.family.children[0].name = "Λενιώ"
        await family.release()
        await saving.value

        #expect(sut.removedChildren.map(\.name) == ["Ίρις", "Νίκος"])
        #expect(sut.hasUnsavedChanges)
    }
}

/// One family, read and changed as the store would: removed children keep their place in the order.
actor FakeFamily: GetProfileUseCase, UpdateFamilyUseCase {
    private var children: [(child: Child, isRemoved: Bool)]
    private var fails = false
    private var failsReading = false
    private(set) var deletedForGood: [UUID] = []
    private var holds = false
    private var released = false
    private var held: CheckedContinuation<Void, Never>?

    init(children: [(Child, Bool)]) {
        self.children = children.map { (child: $0.0, isRemoved: $0.1) }
    }

    func fail() { fails = true }
    func failReading() { failsReading = true }

    /// The next write waits until `release()`.
    func holdNext() { holds = true }

    func release() {
        released = true
        held?.resume()
        held = nil
    }

    private func waitIfHeld() async {
        guard holds else { return }
        holds = false
        if !released { await withCheckedContinuation { held = $0 } }
        released = false
    }

    func execute() async throws -> PlayerProfile? {
        if failsReading { throw StubFailure() }
        return PlayerProfile(
            children: children.filter { !$0.isRemoved }.map(\.child), heroClassID: "h-cool",
            removedChildren: children.filter(\.isRemoved).map(\.child)
        )
    }

    /// Only removals are kept: what these tests need of a save.
    func execute(_ edit: FamilyEdit, on date: Date) async throws {
        await waitIfHeld()
        for index in children.indices where edit.removedIDs.contains(children[index].child.id) {
            children[index].isRemoved = true
        }
    }

    func bringBack(_ id: UUID) async throws {
        await waitIfHeld()
        if fails { throw StubFailure() }
        guard let index = children.firstIndex(where: { $0.child.id == id && $0.isRemoved }) else {
            throw ProfileEditError.notRemoved
        }
        children[index].isRemoved = false
    }

    func deleteForGood(_ id: UUID) throws {
        if fails { throw StubFailure() }
        guard children.contains(where: { $0.child.id == id && $0.isRemoved }) else { throw ProfileEditError.notRemoved }
        children.removeAll { $0.child.id == id }
        deletedForGood.append(id)
    }

    struct StubFailure: Error {}
}

struct FakeBringBack: BringBackChildUseCase {
    let family: FakeFamily
    func execute(childID: UUID) async throws { try await family.bringBack(childID) }
}

struct FakeDeleteForGood: DeleteChildForGoodUseCase {
    let family: FakeFamily
    func execute(childID: UUID, on date: Date) async throws { try await family.deleteForGood(childID) }
}

/// For the tests that never bring back or delete for good.
struct NoFamilyActs: BringBackChildUseCase, DeleteChildForGoodUseCase {
    func execute(childID: UUID) async throws {}
    func execute(childID: UUID, on date: Date) async throws {}
}
