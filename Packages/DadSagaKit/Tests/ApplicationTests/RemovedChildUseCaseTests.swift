import Application
import Domain
import Foundation
import Testing

/// Bringing back and deleting for good, through fakes (ADR-0065 §4). On a store on disk: `RemovedChildTests`.
@Suite("Removed children: use cases")
struct RemovedChildUseCaseTests {
    let lena = Child(name: "Λένα", birthDay: nil)
    let iris = Child(name: "Ίρις", birthDay: nil)
    let photos = SpyPhotoStore()
    let content = StubContentRepository(result: .success(StandingUseCaseTests.catalog))

    func profiles(family: [Child], removed: [Child]) async -> SpyProfileRepository {
        let repository = SpyProfileRepository()
        await repository.seed(PlayerProfile(children: family, heroClassID: "h1", removedChildren: removed))
        return repository
    }

    func deleteForGood(
        _ profiles: SpyProfileRepository, _ progress: SpyProgressRepository, _ standing: InMemoryStanding,
        renewReminders: any RenewWeeklyRemindersUseCase = NoReminders(), offers: FakeSagaOffers = FakeSagaOffers()
    ) -> DefaultDeleteChildForGoodUseCase {
        DefaultDeleteChildForGoodUseCase(
            contentRepository: content, profileRepository: profiles, progressRepository: progress,
            standingRepository: standing, sagaOffers: offers, photoStore: photos, renewReminders: renewReminders
        )
    }

    @Test("Given film offers answered for two children, when one is deleted for good, then no answer names them")
    func forgetsTheFilmAnswers() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let offers = FakeSagaOffers()
        let lenas = "\(lena.id.uuidString)/birthday/1"
        for id in [lenas, "\(iris.id.uuidString)/birthday/2", "\(iris.id.uuidString)/world/w1"] {
            await offers.markAnswered(id)
        }

        try await deleteForGood(repository, SpyProgressRepository(), InMemoryStanding(), offers: offers)
            .execute(childID: iris.id, on: .now)

        #expect(await offers.answered == [lenas])
    }

    @Test("Given a child still in the family, when deleting them for good is refused, then their film answers stay")
    func aRefusalForgetsNothing() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let offers = FakeSagaOffers()
        await offers.markAnswered("\(lena.id.uuidString)/birthday/1")

        await #expect(throws: ProfileEditError.notRemoved) {
            try await deleteForGood(repository, SpyProgressRepository(), InMemoryStanding(), offers: offers)
                .execute(childID: lena.id, on: .now)
        }

        #expect(await offers.answered.count == 1)
    }

    @Test("Given a removed child, when bringing them back, then they are in the family and no longer removed")
    func bringsBack() async throws {
        let repository = await profiles(family: [lena], removed: [iris])

        try await DefaultBringBackChildUseCase(profileRepository: repository).execute(childID: iris.id)

        let stored = try #require(try await repository.fetchProfile())
        #expect(stored.children.map(\.id) == [lena.id, iris.id])
        #expect(stored.removedChildren.isEmpty)
    }

    /// The store refuses, in its own write (ADR-0068 §3); the use case passes its answer on.
    @Test("Given four in the family, when bringing a removed child back, then the store's refusal is passed on")
    func bringingBackIsAdding() async throws {
        let four = (1...4).map { Child(name: "Παιδί \($0)", birthDay: nil) }
        let repository = await profiles(family: four, removed: [iris])

        await #expect(throws: ProfileValidationError.tooManyChildren) {
            try await DefaultBringBackChildUseCase(profileRepository: repository).execute(childID: iris.id)
        }
        #expect(await repository.editCount == 0)
    }

    @Test("Given a child in the family or an unknown id, when bringing back, then notRemoved; before onboarding noProfile")
    func bringsBackOnlyARemovedChild() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let sut = DefaultBringBackChildUseCase(profileRepository: repository)

        await #expect(throws: ProfileEditError.notRemoved) { try await sut.execute(childID: lena.id) }
        await #expect(throws: ProfileEditError.notRemoved) { try await sut.execute(childID: UUID()) }
        await #expect(throws: ProfileEditError.noProfile) {
            try await DefaultBringBackChildUseCase(profileRepository: SpyProfileRepository()).execute(childID: iris.id)
        }
        #expect(await repository.editCount == 0)
    }

    @Test("Given the title came from a removed child's entries, when deleting them for good, then the title is kept first")
    func deletingForGoodKeepsTheTitle() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: iris.id, date: .now))
        let standing = InMemoryStanding()

        try await deleteForGood(repository, progress, standing).execute(childID: iris.id, on: .now)

        #expect(await standing.kept.titleID == "t1")
        let stored = try #require(try await repository.fetchProfile())
        #expect(stored.removedChildren.isEmpty)
        #expect(stored.children == [lena])
    }

    @Test("Given the title can't be kept, when deleting a removed child for good, then nothing is deleted")
    func nothingGoesWhenTheTitleCantBeKept() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: iris.id, date: .now))
        let standing = InMemoryStanding()
        await standing.failKeeping()

        await #expect(throws: StubError.boom) {
            try await deleteForGood(repository, progress, standing).execute(childID: iris.id, on: .now)
        }
        #expect(try await repository.fetchProfile()?.removedChildren == [iris])
        #expect(await repository.editCount == 0)
    }

    @Test("Given a removed child with photos, when deleting them for good, then every photo file is deleted")
    func deletingForGoodDeletesThePhotos() async throws {
        let repository = await profiles(family: [lena], removed: [iris])
        let theirs = try await photos.save(Data("a".utf8))
        let ours = try await photos.save(Data("b".utf8))
        await repository.setPhotosOfRemoved([theirs])

        try await deleteForGood(repository, SpyProgressRepository(), InMemoryStanding()).execute(childID: iris.id, on: .now)

        #expect(await photos.stored.keys.sorted() == [ours])
    }

    @Test("Given a child in the family, when deleting them for good, then notRemoved and nothing is kept or deleted")
    func deletesForGoodOnlyARemovedChild() async throws {
        let repository = await profiles(family: [lena, iris], removed: [])
        let progress = SpyProgressRepository()
        try await progress.add(ProgressEvent(kind: .quest(id: "q1"), childID: iris.id, date: .now))
        let standing = InMemoryStanding()

        await #expect(throws: ProfileEditError.notRemoved) {
            try await deleteForGood(repository, progress, standing).execute(childID: iris.id, on: .now)
        }
        #expect(await standing.writes == 0)
        #expect(await repository.editCount == 0)
        #expect(try await progress.fetchEvents().count == 1)
    }
}
