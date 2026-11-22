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
                heroClasses: [HeroClass(id: "h1", order: 1, title: Stub.text, tagline: Stub.text, look: "hero")]
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
        let child = Child(name: " Νίκος ", birthDay: CalendarDay(today, in: .gmt))

        try await sut.execute(PlayerProfile(children: [child], heroClassID: "h1"), on: today)

        let stored = try await DefaultGetProfileUseCase(repository: repository).execute()
        let trimmed = Child(id: child.id, name: "Νίκος", birthDay: CalendarDay(today, in: .gmt))
        #expect(stored == PlayerProfile(children: [trimmed], heroClassID: "h1"))
    }

    @Test("Given an unknown hero class, when saving, then it throws and nothing is stored")
    func rejectsInvalidProfile() async throws {
        let repository = SpyProfileRepository()
        let sut = DefaultSaveProfileUseCase(contentRepository: content, profileRepository: repository)
        let profile = PlayerProfile(children: [Child(name: "Νίκος", birthDay: CalendarDay(today, in: .gmt))], heroClassID: "nope")

        await #expect(throws: ProfileValidationError.unknownHeroClass("nope")) {
            try await sut.execute(profile, on: today)
        }
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
}

extension ProfileUseCaseTests {
    @Test("Given five children from a copy, when the hero and the family are edited, then both save and the id stays")
    func aFamilyOfFiveCanBeEdited() async throws {
        let repository = SpyProfileRepository()
        let id = UUID()
        let five = (1...5).map { Child(name: "Παιδί \($0)", birthDay: nil) }
        try await repository.save(PlayerProfile(id: id, children: five, heroClassID: "h1"))

        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: repository)
            .execute(heroClassID: "h1", skinTone: .dark, appearance: .standard(for: .dark), on: today)
        try await DefaultUpdateFamilyUseCase(profileRepository: repository)
            .execute(children: Array(five.dropLast()), hasPartner: false, on: today)

        let stored = try #require(try await repository.fetchProfile())
        #expect(stored.id == id)
        #expect(stored.children == Array(five.dropLast()))
        #expect(stored.dadSkinTone == .dark)
        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await DefaultUpdateFamilyUseCase(profileRepository: repository)
                .execute(children: five, hasPartner: false, on: today)
        }
    }
}
