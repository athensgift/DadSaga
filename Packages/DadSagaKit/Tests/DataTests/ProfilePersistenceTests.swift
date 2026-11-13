import Domain
import Foundation
import Testing
@testable import Data

@Suite("Hero classes content")
struct HeroClassContentTests {
    @Test("Given the bundled JSON, when fetching, then the six hero classes load in order with text in both languages")
    func loadsHeroClasses() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        #expect(catalog.heroClasses.map(\.id) == ["h-super", "h-cool", "h-strong", "h-smart", "h-chef", "h-fixer"])
        for hero in catalog.heroClasses {
            #expect(!hero.title.el.isEmpty && !hero.title.en.isEmpty)
            #expect(!hero.tagline.el.isEmpty && !hero.tagline.en.isEmpty)
        }
    }
}

/// Serialized: creating several SwiftData containers for the same model at once can crash the test process.
@Suite("LocalStore", .serialized)
struct LocalStoreTests {
    let birth = Date(timeIntervalSince1970: 1_000_000)

    @Test("Given an empty store, when fetching, then there is no profile")
    func emptyStore() async throws {
        let sut = try LocalStore.inMemory().profiles
        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given a saved profile, when fetching, then the same profile is returned")
    func roundTrip() async throws {
        let sut = try LocalStore.inMemory().profiles
        let profile = PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-cool")

        try await sut.save(profile)

        #expect(try await sut.fetchProfile() == profile)
    }

    @Test("Given an existing profile, when saving again, then it is replaced rather than duplicated")
    func saveReplaces() async throws {
        let sut = try LocalStore.inMemory().profiles
        try await sut.save(PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-cool"))
        let updated = PlayerProfile(child: Child(name: "Άννα", birthDate: birth), heroClassID: "h-smart")

        try await sut.save(updated)

        #expect(try await sut.fetchProfile() == updated)
    }

    @Test("Given a saved profile, when deleting, then the store is empty again")
    func delete() async throws {
        let sut = try LocalStore.inMemory().profiles
        try await sut.save(PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-cool"))

        try await sut.deleteProfile()

        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given stored events, when fetching, then they come back oldest first with their ids and kinds")
    func progressRoundTrip() async throws {
        let sut = try LocalStore.inMemory().progress
        let later = ProgressEvent(kind: .boss(id: "b1"), date: birth.addingTimeInterval(60))
        let earlier = ProgressEvent(kind: .quest(id: "q1"), date: birth)

        try await sut.add(later)
        try await sut.add(earlier)

        #expect(try await sut.fetchEvents() == [earlier, later])
    }

    @Test("Given stored events, when deleting all, then the log is empty")
    func progressDeleteAll() async throws {
        let sut = try LocalStore.inMemory().progress
        try await sut.add(ProgressEvent(kind: .first(id: "f1"), date: birth))

        try await sut.deleteAll()

        #expect(try await sut.fetchEvents().isEmpty)
    }

    @Test("Given a record of a kind this version does not know, when mapping, then it is skipped")
    func unknownKindIsSkipped() {
        let record = ProgressEventRecord(event: ProgressEvent(kind: .quest(id: "q1"), date: birth))
        record.kind = "future-kind"
        #expect(record.toDomain() == nil)
    }
}
