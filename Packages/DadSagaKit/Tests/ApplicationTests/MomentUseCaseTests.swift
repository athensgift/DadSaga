import Application
import Domain
import Foundation
import Testing

@Suite("Moment use cases")
struct MomentUseCaseTests {
    static let first = FirstMoment(id: "f-steps", order: 1, emoji: "👣", title: Stub.text, xp: 30, companionTrait: "walk")
    let today = Date(timeIntervalSince1970: 1_000_000)
    let content = StubContentRepository(
        result: .success(ContentCatalog(worlds: [], quests: [], bosses: [], firsts: [Self.first]))
    )
    let repository = SpyProgressRepository()
    let photos = SpyPhotoStore()
    let child = UUID()
    let firstID = Self.first.id

    var capture: DefaultCaptureMomentUseCase {
        DefaultCaptureMomentUseCase(
            contentRepository: content,
            progressRepository: repository,
            profileRepository: TheDad(),
            photoStore: photos
        )
    }

    var update: DefaultUpdateMomentUseCase {
        DefaultUpdateMomentUseCase(progressRepository: repository, photoStore: photos)
    }

    func request(child: UUID? = nil, date: Date? = nil) -> CaptureMomentRequest {
        CaptureMomentRequest(firstID: firstID, childID: child ?? self.child, date: date ?? today)
    }

    /// A moment captured today, then given a note and photos the way the sheet's second step does.
    func captured(note: String? = nil, photos added: [Data] = []) async throws -> ProgressEvent {
        _ = try await capture.execute(request(), now: today)
        let moment = try #require(try await repository.fetchEvents().first)
        try await update.execute(
            momentID: moment.id, happenedOn: moment.date, note: note, photos: added.map(EntryPhoto.added), now: today
        )
        return try #require(try await repository.fetchEvents().first)
    }

    @Test("Given a first not yet captured, when capturing it with a past date, then it is stored with its XP and nothing else")
    func captures() async throws {
        let lastWeek = today.addingTimeInterval(-7 * 86_400)

        let change = try await capture.execute(request(date: lastWeek), now: today)

        #expect(change.gainedXP == 30)
        let event = try #require(try await repository.fetchEvents().first)
        #expect(change.eventID == event.id)
        #expect(event.kind == .first(id: firstID))
        #expect(event.childID == child)
        #expect(event.date == lastWeek)
        #expect(event.note == nil)
        #expect(event.photoIDs.isEmpty)
        #expect(await photos.saveCount == 0)
    }

    @Test("Given a captured first, when its second step adds a note and photos, then they are stored in order")
    func detailsAfterCapture() async throws {
        let event = try await captured(note: "  Γέλασε! ", photos: [Data([1, 2, 3]), Data([4])])

        #expect(event.note == "Γέλασε!")
        #expect(event.photoIDs.count == 2)
        #expect(await photos.stored[try #require(event.coverPhotoID)] == Data([1, 2, 3]))
    }

    @Test("Given a first already captured for this child, when capturing again, then it throws; another child is fine")
    func oncePerChild() async throws {
        _ = try await capture.execute(request(), now: today)

        await #expect(throws: MomentError.alreadyCaptured(firstID)) {
            try await capture.execute(request(), now: today)
        }
        _ = try await capture.execute(request(child: UUID()), now: today)
        #expect(try await repository.fetchEvents().count == 2)
    }

    @Test("Given a date after today or an unknown first, when capturing, then it throws and nothing is stored")
    func rejects() async throws {
        await #expect(throws: MomentError.dateInFuture) {
            try await capture.execute(request(date: today.addingTimeInterval(86_400)), now: today)
        }
        await #expect(throws: MomentError.unknownFirst("nope")) {
            let unknown = CaptureMomentRequest(firstID: "nope", childID: child, date: today)
            return try await capture.execute(unknown, now: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given a moment with a photo, when replacing the photo and changing date and note, then the old photo is deleted")
    func updateReplacesPhoto() async throws {
        let moment = try await captured(note: "πριν", photos: [Data([1])])
        let sut = update
        let yesterday = today.addingTimeInterval(-86_400)

        try await sut.execute(momentID: moment.id, happenedOn: yesterday, note: "μετά", photos: [.added(Data([2]))], now: today)

        let updated = try #require(try await repository.fetchEvents().first)
        #expect(updated.id == moment.id)
        #expect(updated.kind == moment.kind)
        #expect(updated.childID == child)
        #expect(updated.date == yesterday)
        #expect(updated.note == "μετά")
        #expect(updated.photoIDs.count == 1)
        #expect(updated.photoIDs != moment.photoIDs)
        #expect(await photos.stored == [try #require(updated.coverPhotoID): Data([2])])
    }

    @Test("Given a moment captured by the dad, then it is his; given a partner's entry, when edited, then it stays theirs")
    func authorsStay() async throws {
        let moment = try await captured()
        #expect(moment.authorID == .testDad)

        let partner = UUID()
        let theirs = ProgressEvent(authorID: partner, kind: .quest(id: "q1"), childID: child, date: today)
        try await repository.add(theirs)
        try await DefaultUpdateJournalUseCase(progressRepository: repository, photoStore: photos)
            .execute(eventID: theirs.id, note: "μαζί", photos: [.added(Data([3]))])
        try await update.execute(momentID: moment.id, happenedOn: moment.date, note: "x", photos: [], now: today)

        let events = try await repository.fetchEvents()
        #expect(events.first { $0.id == theirs.id }?.authorID == partner)
        #expect(events.first { $0.id == theirs.id }?.note == "μαζί")
        #expect(events.first { $0.id == moment.id }?.authorID == .testDad)
    }

    @Test("Given saving fails, when replacing a moment's photo, then the new photo is removed and the old one stays")
    func failedUpdateLeavesNoPhoto() async throws {
        let moment = try await captured(photos: [Data([1])])
        let sut = DefaultUpdateMomentUseCase(progressRepository: FailingUpdates(repository), photoStore: photos)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await sut.execute(momentID: moment.id, happenedOn: today, note: nil, photos: [.added(Data([2]))], now: today)
        }

        #expect(await photos.stored == [try #require(moment.coverPhotoID): Data([1])])
    }

    @Test("Given saving fails, when replacing an entry's photo from the journal, then no new photo is left behind")
    func failedJournalUpdateLeavesNoPhoto() async throws {
        let moment = try await captured(photos: [Data([1])])
        let sut = DefaultUpdateJournalUseCase(progressRepository: FailingUpdates(repository), photoStore: photos)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await sut.execute(eventID: moment.id, note: "x", photos: [.added(Data([2]))])
        }

        #expect(await photos.stored == [try #require(moment.coverPhotoID): Data([1])])
    }

    @Test("Given a moment with a photo, when keeping or removing the photo, then it stays or is deleted")
    func updateKeepsOrRemovesPhoto() async throws {
        let moment = try await captured(photos: [Data([1])])
        let sut = update

        try await sut.execute(
            momentID: moment.id, happenedOn: today, note: nil, photos: moment.photoIDs.map(EntryPhoto.kept), now: today
        )
        #expect(try await repository.fetchEvents().first?.photoIDs == moment.photoIDs)
        #expect(await photos.stored.count == 1)

        try await sut.execute(momentID: moment.id, happenedOn: today, note: nil, photos: [], now: today)
        #expect(try await repository.fetchEvents().first?.photoIDs == [])
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a moment, when deleting it, then the event, its photo and its XP are gone")
    func deletes() async throws {
        let moment = try await captured(photos: [Data([1])])

        try await DefaultDeleteEventUseCase(
            contentRepository: StubContentRepository(result: .success(Stub.catalog)), profileRepository: TheDad(),
            progressRepository: repository,
            standingRepository: InMemoryStanding(),
            photoStore: photos
        ).execute(eventID: moment.id)

        #expect(try await repository.fetchEvents().isEmpty)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a quest, when deleting it, then the event and its XP are gone")
    func deletesQuest() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))
        let quest = try #require(try await repository.fetchEvents().first)

        try await DefaultDeleteEventUseCase(
            contentRepository: StubContentRepository(result: .success(Stub.catalog)), profileRepository: TheDad(),
            progressRepository: repository,
            standingRepository: InMemoryStanding(),
            photoStore: photos
        ).execute(eventID: quest.id)

        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given an unknown id, when deleting, then unknownEvent is thrown and nothing changes")
    func unknownEvent() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))

        await #expect(throws: ProgressError.unknownEvent) {
            try await DefaultDeleteEventUseCase(
                contentRepository: StubContentRepository(result: .success(Stub.catalog)), profileRepository: TheDad(),
                progressRepository: repository,
                standingRepository: InMemoryStanding(),
                photoStore: photos
            ).execute(eventID: UUID())
        }
        #expect(try await repository.fetchEvents().count == 1)
    }

    @Test("Given an id that is not a moment, when updating, then unknownMoment is thrown")
    func unknownMoment() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))
        await #expect(throws: MomentError.unknownMoment) {
            try await DefaultUpdateMomentUseCase(progressRepository: repository, photoStore: photos)
                .execute(momentID: UUID(), happenedOn: today, note: nil, photos: [], now: today)
        }
        #expect(try await repository.fetchEvents().count == 1)
    }

    @Test("Given a stored photo, when getting it for a small frame, then a thumbnail of that size is returned")
    func getsPhoto() async throws {
        let id = try await photos.save(Data([7]))
        let sut = DefaultGetPhotoUseCase(photoStore: photos)
        #expect(await sut.execute(id: id, maxPixelSize: 192) == Data("thumb192:".utf8) + Data([7]))
        #expect(await sut.execute(id: "missing", maxPixelSize: 192) == nil)
    }
}

/// Reads from the wrapped repository; every update fails, like a full disk.
struct FailingUpdates: ProgressRepository {
    struct Failure: Error {}
    let base: any ProgressRepository

    init(_ base: any ProgressRepository) { self.base = base }

    func fetchEvents() async throws -> [ProgressEvent] { try await base.fetchEvents() }
    func referencedPhotoIDs() async throws -> Set<String> { try await base.referencedPhotoIDs() }
    func add(_ event: ProgressEvent) async throws { throw Failure() }
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool { throw Failure() }
    func update(_ event: ProgressEvent) async throws { throw Failure() }
    func delete(id: UUID) async throws { throw Failure() }
}

@Suite("GetTimelineUseCase")
struct GetTimelineUseCaseTests {
    let content = StubContentRepository(result: .success(Stub.catalog))
    let family = Child(name: "Λένα", birthDay: nil)

    func saga(removed: [Child] = [], events: [ProgressEvent]) -> StoredSaga {
        StoredSaga(
            profile: PlayerProfile(children: [family], heroClassID: "h1"), removedChildren: removed, events: events,
            outfit: Outfit(), kept: KeptStanding()
        )
    }

    @Test("Given stored events, when executing, then the timeline is built from them and the catalog")
    func buildsTimeline() async throws {
        let quest = try #require(Stub.catalog.quests.first)
        let events = [ProgressEvent(kind: .quest(id: quest.id), childID: family.id, date: .now)]
        let sut = DefaultGetTimelineUseCase(contentRepository: content, wholeSaga: StoredWholeSaga(saga: saga(events: events)))

        let entries = try await sut.execute()

        #expect(entries.map(\.xp) == [quest.xp])
    }

    @Test("Given entries of a removed child and of a child deleted, when executing, then only the removed one's are left out")
    func removedChildrenAreLeftOut() async throws {
        let quest = try #require(Stub.catalog.quests.first)
        let removed = Child(name: "Ίρις", birthDay: nil)
        let ours = ProgressEvent(kind: .quest(id: quest.id), childID: family.id, date: .now)
        let deletedChilds = ProgressEvent(kind: .quest(id: quest.id), childID: UUID(), date: .now.addingTimeInterval(-60))
        let removedChilds = ProgressEvent(kind: .quest(id: quest.id), childID: removed.id, date: .now)
        let stored = saga(removed: [removed], events: [deletedChilds, ours, removedChilds])

        let entries = try await DefaultGetTimelineUseCase(contentRepository: content, wholeSaga: StoredWholeSaga(saga: stored))
            .execute()
        let none = try await DefaultGetTimelineUseCase(contentRepository: content, wholeSaga: StoredWholeSaga(saga: nil))
            .execute()

        #expect(Set(entries.map(\.id)) == [ours.id, deletedChilds.id])
        #expect(none.isEmpty)
    }
}

/// A saga as `WholeSagaRepository` reads it; writes are not expected.
struct StoredWholeSaga: WholeSagaRepository {
    let saga: StoredSaga?

    func readAll() async throws -> StoredSaga? { saga }
    func replaceAll(with saga: StoredSaga) async throws { Issue.record("Not expected") }
    func eraseAll() async throws { Issue.record("Not expected") }
}
