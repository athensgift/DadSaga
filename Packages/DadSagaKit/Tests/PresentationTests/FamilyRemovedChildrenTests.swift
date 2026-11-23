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

    func makeSUT(_ family: FakeFamily, locale: String = "el_GR") -> FamilyViewModel {
        FamilyViewModel(
            getProfile: family, updateFamily: update, bringBack: FakeBringBack(family: family),
            deleteForGood: FakeDeleteForGood(family: family),
            locale: Locale(identifier: locale), now: HeroStub.today, timeZone: .gmt, onSaved: {}
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
}

/// One family, read and changed as the store would: removed children keep their place in the order.
actor FakeFamily: GetProfileUseCase {
    private var children: [(child: Child, isRemoved: Bool)]
    private var fails = false
    private(set) var deletedForGood: [UUID] = []

    init(children: [(Child, Bool)]) {
        self.children = children.map { (child: $0.0, isRemoved: $0.1) }
    }

    func fail() { fails = true }

    func execute() async throws -> PlayerProfile? {
        PlayerProfile(
            children: children.filter { !$0.isRemoved }.map(\.child), heroClassID: "h-cool",
            removedChildren: children.filter(\.isRemoved).map(\.child)
        )
    }

    func bringBack(_ id: UUID) throws {
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
    func execute(childID: UUID) async throws { try await family.deleteForGood(childID) }
}

/// For the tests that never bring back or delete for good.
struct NoFamilyActs: BringBackChildUseCase, DeleteChildForGoodUseCase {
    func execute(childID: UUID) async throws {}
}
