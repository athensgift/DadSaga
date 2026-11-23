import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// The versioned store, and what happens when it cannot be opened (ADR-0026).
@Suite("Versioned store", .serialized)
struct StoreVersioningTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-versioning-" + UUID().uuidString)
    var storeURL: URL { directory.appending(path: "DadSaga.store") }

    /// Writes rows straight into a store, bypassing the repositories, then closes it.
    func writeRows(_ insert: (ModelContext) -> Void) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: Schema(versionedSchema: CurrentSchema.self),
            migrationPlan: DadSagaMigrationPlan.self,
            configurations: [ModelConfiguration(url: storeURL, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        insert(context)
        try context.save()
    }

    @Test("Given the store folder cannot be created, when reading, then it throws; once it can, the same store opens")
    func retriesAfterFailure() async throws {
        try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a folder".utf8).write(to: directory)
        let store = LocalStore.live(in: directory)

        await #expect(throws: (any Error).self) { try await store.profiles.fetchProfile() }
        #expect(try Data(contentsOf: directory) == Data("not a folder".utf8))

        try FileManager.default.removeItem(at: directory)
        #expect(try await store.profiles.fetchProfile() == nil)
    }

    @Test("Given no folder for the saga, when reading, then it throws appGroupUnavailable, again on the next call")
    func unknownFolderThrows() async throws {
        let store = LocalStore.live(directory: { throw SharedContainerError.appGroupUnavailable }, readOnly: false)

        await #expect(throws: SharedContainerError.appGroupUnavailable) { try await store.progress.fetchEvents() }
        await #expect(throws: SharedContainerError.appGroupUnavailable) { try await store.profiles.fetchProfile() }
        #expect(!FileManager.default.fileExists(atPath: directory.path()))
    }

    @Test("Given a store file that is not a database, when reading, then it throws and the file is unchanged")
    func damagedFileIsLeftAlone() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let junk = Data(repeating: 0x42, count: 4096)
        try junk.write(to: storeURL)

        await #expect(throws: (any Error).self) { try await LocalStore.live(in: directory).progress.fetchEvents() }
        #expect(try Data(contentsOf: storeURL) == junk)
    }

    @Test("Given a removed child, when an edit renames, removes or re-adds their id, then their row stays removed and as it was")
    func familySaveNeverBringsBack() async throws {
        let lena = Child(name: "Λένα", birthDay: .day(2020, 1, 1))
        let iris = Child(name: "Ίρις", birthDay: nil)
        let store = LocalStore.live(in: directory)
        try await store.wholeSaga.replaceAll(with: StoredSaga(
            profile: PlayerProfile(children: [lena], heroClassID: "chef"), removedChildren: [iris], events: [],
            outfit: Outfit(), kept: KeptStanding()
        ))
        var renamed = iris
        renamed.name = "Άλλη"

        try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
        try await store.profiles.save(FamilyEdit(removedIDs: [iris.id]))
        try await store.profiles.save(FamilyEdit(added: [renamed]))

        #expect(try await store.profiles.fetchProfile()?.children == [lena])
        #expect(try await store.wholeSaga.readAll()?.removedChildren == [iris])
        #expect(try storedRowCount(ChildRecord.self, at: storeURL) == 2)
    }

    @Test("Given a dad onboarded, when his hero and family are edited and the store reopened, then his id is the first")
    func theProfileKeepsItsID() async throws {
        let id = UUID()
        let lena = Child(name: "Λένα", birthDay: .day(2020, 1, 1))
        try await LocalStore.live(in: directory).profiles.create(PlayerProfile(id: id, children: [lena], heroClassID: "chef"))

        try await LocalStore.live(in: directory).profiles.save(HeroEdit(heroClassID: "h-cool", dadSkinTone: .dark))
        try await LocalStore.live(in: directory).profiles.save(FamilyEdit(added: [Child(name: "Νίκος", birthDay: nil)]))

        let reopened = try #require(try await LocalStore.live(in: directory).profiles.fetchProfile())
        #expect(reopened.id == id)
        #expect(reopened.heroClassID == "h-cool")
        #expect(reopened.children.count == 2)
    }

    @Test("Given a saved family, when a child is renamed, one removed and one added, then that family is read, the new one last")
    func saveUpdatesInPlace() async throws {
        let store = LocalStore.live(in: directory)
        let lena = Child(name: "Λένα", birthDay: .day(2020, 1, 1))
        let nikos = Child(name: "Νίκος", birthDay: .day(2020, 1, 1))
        try await store.profiles.create(PlayerProfile(children: [lena, nikos], heroClassID: "chef"))
        var renamed = lena
        renamed.name = "Ελένη"
        let anna = Child(name: "Άννα", birthDay: CalendarDay(.now, in: .gmt))

        try await store.profiles.save(FamilyEdit(
            added: [anna], removedIDs: [nikos.id], changed: [ChildEdit(child: renamed, fields: [.name])]
        ))

        #expect(try await store.profiles.fetchProfile() == PlayerProfile(children: [renamed, anna], heroClassID: "chef"))
    }

    @Test("Given a child not born yet, when the family is saved with a birth day, then the same child reads back born on it")
    func savingABirthDayUpdatesTheChild() async throws {
        let baby = Child(name: "Μπέμπης", birthDay: nil)
        try await LocalStore.live(in: directory).profiles.create(PlayerProfile(children: [baby], heroClassID: "chef"))
        var born = baby
        born.birthDay = .day(2026, 11, 1)

        try await LocalStore.live(in: directory).profiles.save(FamilyEdit(changed: [ChildEdit(child: born, fields: [.birthDay])]))

        let children = try await LocalStore.live(in: directory).profiles.fetchProfile()?.children
        #expect(children == [born])
        #expect(children?.first?.id == baby.id)
    }

    @Test("Given a born child, when the family is saved without a birth day, then the child reads back not born yet")
    func clearingABirthDayUpdatesTheChild() async throws {
        let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2))
        try await LocalStore.live(in: directory).profiles.create(PlayerProfile(children: [lena], heroClassID: "chef"))
        var unborn = lena
        unborn.birthDay = nil

        try await LocalStore.live(in: directory).profiles.save(
            FamilyEdit(changed: [ChildEdit(child: unborn, fields: [.birthDay])])
        )

        let child = try await LocalStore.live(in: directory).profiles.fetchProfile()?.children.first
        #expect(child?.id == lena.id)
        #expect(child?.isBorn == false)
    }

    @Test("Given a saved dad, when his look and partner answer change, then the new ones come back after a reopen")
    func savingTheLookUpdatesTheProfile() async throws {
        let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2))
        var dad = PlayerProfile(children: [lena], heroClassID: "chef", dadSkinTone: .medium)
        try await LocalStore.live(in: directory).profiles.create(dad)
        dad.dadAppearance = DadAppearance(hair: .curly, hairColor: .grey, beard: .none, glasses: .round)
        dad.hasPartner = !dad.hasPartner

        try await LocalStore.live(in: directory).profiles.save(
            HeroEdit(hair: .curly, hairColor: .grey, beard: DadAppearance.Beard.none, glasses: .round)
        )
        try await LocalStore.live(in: directory).profiles.save(FamilyEdit(hasPartner: dad.hasPartner))

        #expect(try await LocalStore.live(in: directory).profiles.fetchProfile() == dad)
    }
}
