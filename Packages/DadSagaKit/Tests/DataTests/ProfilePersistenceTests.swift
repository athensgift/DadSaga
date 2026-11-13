import Domain
import Foundation
import Testing
@testable import Data

@Suite("Hero classes content")
struct HeroClassContentTests {
    @Test("Given the bundled JSON, when fetching, then the three hero classes load in order with text in both languages")
    func loadsHeroClasses() async throws {
        let catalog = try await BundledContentRepository().fetchCatalog()
        #expect(catalog.heroClasses.map(\.id) == ["h-knight", "h-mage", "h-ranger"])
        for hero in catalog.heroClasses {
            #expect(!hero.title.el.isEmpty && !hero.title.en.isEmpty)
            #expect(!hero.tagline.el.isEmpty && !hero.tagline.en.isEmpty)
        }
    }
}

@Suite("SwiftDataProfileRepository")
struct SwiftDataProfileRepositoryTests {
    let birth = Date(timeIntervalSince1970: 1_000_000)

    @Test("Given an empty store, when fetching, then there is no profile")
    func emptyStore() async throws {
        let sut = try SwiftDataProfileRepository.inMemory()
        #expect(try await sut.fetchProfile() == nil)
    }

    @Test("Given a saved profile, when fetching, then the same profile is returned")
    func roundTrip() async throws {
        let sut = try SwiftDataProfileRepository.inMemory()
        let profile = PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-mage")

        try await sut.save(profile)

        #expect(try await sut.fetchProfile() == profile)
    }

    @Test("Given an existing profile, when saving again, then it is replaced rather than duplicated")
    func saveReplaces() async throws {
        let sut = try SwiftDataProfileRepository.inMemory()
        try await sut.save(PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-mage"))
        let updated = PlayerProfile(child: Child(name: "Άννα", birthDate: birth), heroClassID: "h-ranger")

        try await sut.save(updated)

        #expect(try await sut.fetchProfile() == updated)
    }

    @Test("Given a saved profile, when deleting, then the store is empty again")
    func delete() async throws {
        let sut = try SwiftDataProfileRepository.inMemory()
        try await sut.save(PlayerProfile(child: Child(name: "Νίκος", birthDate: birth), heroClassID: "h-mage"))

        try await sut.deleteProfile()

        #expect(try await sut.fetchProfile() == nil)
    }
}
