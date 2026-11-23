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
    /// How many edits reached the store.
    private(set) var editCount = 0

    func fetchProfile() async throws -> PlayerProfile? {
        profile
    }

    /// A test's given: any profile, over whatever is stored.
    func seed(_ profile: PlayerProfile) {
        self.profile = profile
    }

    func create(_ profile: PlayerProfile) async throws {
        guard self.profile == nil else { throw ProfileEditError.profileExists }
        self.profile = profile
    }

    func save(_ edit: FamilyEdit) async throws {
        guard var profile else { throw ProfileEditError.noProfile }
        profile.children = edit.applied(to: profile.children)
        if let hasPartner = edit.hasPartner { profile.hasPartner = hasPartner }
        self.profile = profile
        editCount += 1
    }

    func save(_ edit: HeroEdit) async throws {
        guard let profile else { throw ProfileEditError.noProfile }
        self.profile = edit.applied(to: profile)
        editCount += 1
    }
}

extension ProfileUseCaseTests {
    @Test("Given five children from a copy, when the hero and the family are edited, then both save and the id stays")
    func aFamilyOfFiveCanBeEdited() async throws {
        let repository = SpyProfileRepository()
        let id = UUID()
        let five = (1...5).map { Child(name: "Παιδί \($0)", birthDay: nil) }
        await repository.seed(PlayerProfile(id: id, children: five, heroClassID: "h1"))
        let family = DefaultUpdateFamilyUseCase(profileRepository: repository)

        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: repository)
            .execute(HeroEdit(dadSkinTone: .dark))
        try await family.execute(FamilyEdit(removedIDs: [five[4].id], hasPartner: false), on: today)

        let stored = try #require(try await repository.fetchProfile())
        #expect(stored.id == id)
        #expect(stored.children == Array(five.dropLast()))
        #expect(stored.dadSkinTone == .dark)
        #expect(!stored.hasPartner)
        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await family.execute(FamilyEdit(added: [five[4]]), on: today)
        }
        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await family.execute(FamilyEdit(added: [Child(name: "Έκτο", birthDay: nil)]), on: today)
        }
        #expect(try await repository.fetchProfile()?.children == Array(five.dropLast()))
    }

    @Test("Given a stored family, when an empty edit saves, then nothing reaches the store")
    func emptyEditSavesNothing() async throws {
        let repository = SpyProfileRepository()
        await repository.seed(PlayerProfile(children: [Child(name: "Λένα", birthDay: nil)], heroClassID: "h1"))

        try await DefaultUpdateFamilyUseCase(profileRepository: repository).execute(FamilyEdit(), on: today)
        try await DefaultUpdateHeroUseCase(contentRepository: content, profileRepository: repository).execute(HeroEdit())

        #expect(await repository.editCount == 0)
    }

    @Test("Given a family of one, when an edit removes that child, then noChildren is thrown and the child stays")
    func editLeavingNoneIsRefused() async throws {
        let repository = SpyProfileRepository()
        let lena = Child(name: "Λένα", birthDay: nil)
        await repository.seed(PlayerProfile(children: [lena], heroClassID: "h1"))

        await #expect(throws: ProfileValidationError.noChildren) {
            try await DefaultUpdateFamilyUseCase(profileRepository: repository)
                .execute(FamilyEdit(removedIDs: [lena.id]), on: today)
        }
        #expect(try await repository.fetchProfile()?.children == [lena])
    }
}
