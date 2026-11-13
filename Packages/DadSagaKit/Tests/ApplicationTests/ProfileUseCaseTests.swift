import Application
import Domain
import Foundation
import Testing

@Suite("Profile use cases")
struct ProfileUseCaseTests {
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(
        result: .success(
            ContentCatalog(
                worlds: [],
                quests: [],
                bosses: [],
                firsts: [],
                heroClasses: [HeroClass(id: "h1", order: 1, title: Stub.text, tagline: Stub.text)]
            )
        )
    )

    @Test("Given no stored profile, when getting it, then nil is returned")
    func noProfile() async throws {
        let sut = DefaultGetProfileUseCase(repository: SpyProfileRepository())
        #expect(try await sut.execute() == nil)
    }

    @Test("Given a valid profile, when saving, then the trimmed profile is stored and can be read back")
    func savesValidProfile() async throws {
        let repository = SpyProfileRepository()
        let sut = DefaultSaveProfileUseCase(contentRepository: content, profileRepository: repository)
        let child = Child(name: " Νίκος ", birthDate: today)

        try await sut.execute(PlayerProfile(child: child, heroClassID: "h1"), on: today)

        let stored = try await DefaultGetProfileUseCase(repository: repository).execute()
        #expect(stored == PlayerProfile(child: Child(name: "Νίκος", birthDate: today), heroClassID: "h1"))
    }

    @Test("Given an unknown hero class, when saving, then it throws and nothing is stored")
    func rejectsInvalidProfile() async throws {
        let repository = SpyProfileRepository()
        let sut = DefaultSaveProfileUseCase(contentRepository: content, profileRepository: repository)
        let profile = PlayerProfile(child: Child(name: "Νίκος", birthDate: today), heroClassID: "nope")

        await #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try await sut.execute(profile, on: today)
        }
        #expect(try await repository.fetchProfile() == nil)
    }

    @Test("Given a stored profile, when resetting, then no profile is left")
    func reset() async throws {
        let repository = SpyProfileRepository()
        try await repository.save(PlayerProfile(child: Child(name: "Νίκος", birthDate: today), heroClassID: "h1"))

        try await DefaultResetProfileUseCase(repository: repository).execute()

        #expect(try await repository.fetchProfile() == nil)
    }
}

actor SpyProfileRepository: ProfileRepository {
    private var profile: PlayerProfile?

    func fetchProfile() async throws -> PlayerProfile? {
        profile
    }

    func save(_ profile: PlayerProfile) async throws {
        self.profile = profile
    }

    func deleteProfile() async throws {
        profile = nil
    }
}
