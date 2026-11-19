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
        DefaultCaptureMomentUseCase(contentRepository: content, progressRepository: repository, photoStore: photos)
    }

    func request(child: UUID? = nil, date: Date? = nil, note: String? = nil, photo: Data? = nil) -> CaptureMomentRequest {
        CaptureMomentRequest(firstID: firstID, childID: child ?? self.child, date: date ?? today, note: note, photo: photo)
    }

    @Test("Given a first not yet captured, when capturing it with a past date, note and photo, then all are stored")
    func captures() async throws {
        let lastWeek = today.addingTimeInterval(-7 * 86_400)

        let change = try await capture.execute(request(date: lastWeek, note: "  Γέλασε! ", photo: Data([1, 2, 3])), now: today)

        #expect(change.gainedXP == 30)
        let event = try #require(try await repository.fetchEvents().first)
        #expect(event.kind == .first(id: firstID))
        #expect(event.childID == child)
        #expect(event.date == lastWeek)
        #expect(event.note == "Γέλασε!")
        #expect(await photos.stored == [try #require(event.photoID): Data([1, 2, 3])])
        #expect(change.after.moments(for: child).map(\.photoID) == [event.photoID])
    }

    @Test("Given a blank note and no photo, when capturing, then neither is stored")
    func blankNote() async throws {
        _ = try await capture.execute(request(note: "   "), now: today)
        let event = try #require(try await repository.fetchEvents().first)
        #expect(event.note == nil)
        #expect(event.photoID == nil)
    }

    @Test("Given a first already captured for this child, when capturing again, then it throws; another child is fine")
    func oncePerChild() async throws {
        _ = try await capture.execute(request(), now: today)

        await #expect(throws: MomentError.alreadyCaptured(firstID)) {
            try await capture.execute(request(photo: Data([9])), now: today)
        }
        #expect(await photos.saveCount == 0)
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
        _ = try await capture.execute(request(note: "πριν", photo: Data([1])), now: today)
        let moment = try #require(try await repository.fetchEvents().first)
        let sut = DefaultUpdateMomentUseCase(progressRepository: repository, photoStore: photos)
        let yesterday = today.addingTimeInterval(-86_400)

        try await sut.execute(momentID: moment.id, happenedOn: yesterday, note: "μετά", photo: .replace(Data([2])), now: today)

        let updated = try #require(try await repository.fetchEvents().first)
        #expect(updated.id == moment.id)
        #expect(updated.kind == moment.kind)
        #expect(updated.childID == child)
        #expect(updated.date == yesterday)
        #expect(updated.note == "μετά")
        #expect(updated.photoID != moment.photoID)
        #expect(await photos.stored == [try #require(updated.photoID): Data([2])])
    }

    @Test("Given saving fails, when replacing a moment's photo, then the new photo is removed and the old one stays")
    func failedUpdateLeavesNoPhoto() async throws {
        _ = try await capture.execute(request(photo: Data([1])), now: today)
        let moment = try #require(try await repository.fetchEvents().first)
        let sut = DefaultUpdateMomentUseCase(progressRepository: FailingUpdates(repository), photoStore: photos)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await sut.execute(momentID: moment.id, happenedOn: today, note: nil, photo: .replace(Data([2])), now: today)
        }

        #expect(await photos.stored == [try #require(moment.photoID): Data([1])])
    }

    @Test("Given saving fails, when replacing an entry's photo from the journal, then no new photo is left behind")
    func failedJournalUpdateLeavesNoPhoto() async throws {
        _ = try await capture.execute(request(photo: Data([1])), now: today)
        let moment = try #require(try await repository.fetchEvents().first)
        let sut = DefaultUpdateJournalUseCase(progressRepository: FailingUpdates(repository), photoStore: photos)

        await #expect(throws: FailingUpdates.Failure.self) {
            try await sut.execute(eventID: moment.id, note: "x", photo: .replace(Data([2])))
        }

        #expect(await photos.stored == [try #require(moment.photoID): Data([1])])
    }

    @Test("Given a moment with a photo, when keeping or removing the photo, then it stays or is deleted")
    func updateKeepsOrRemovesPhoto() async throws {
        _ = try await capture.execute(request(photo: Data([1])), now: today)
        let moment = try #require(try await repository.fetchEvents().first)
        let sut = DefaultUpdateMomentUseCase(progressRepository: repository, photoStore: photos)

        try await sut.execute(momentID: moment.id, happenedOn: today, note: nil, photo: .keep, now: today)
        #expect(try await repository.fetchEvents().first?.photoID == moment.photoID)
        #expect(await photos.stored.count == 1)

        try await sut.execute(momentID: moment.id, happenedOn: today, note: nil, photo: .remove, now: today)
        #expect(try await repository.fetchEvents().first?.photoID == nil)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a moment, when deleting it, then the event, its photo and its XP are gone")
    func deletes() async throws {
        _ = try await capture.execute(request(photo: Data([1])), now: today)
        let moment = try #require(try await repository.fetchEvents().first)

        try await DefaultDeleteEventUseCase(progressRepository: repository, photoStore: photos).execute(eventID: moment.id)

        #expect(try await repository.fetchEvents().isEmpty)
        #expect(await photos.stored.isEmpty)
    }

    @Test("Given a quest, when deleting it, then the event and its XP are gone")
    func deletesQuest() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))
        let quest = try #require(try await repository.fetchEvents().first)

        try await DefaultDeleteEventUseCase(progressRepository: repository, photoStore: photos).execute(eventID: quest.id)

        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given an unknown id, when deleting, then unknownEvent is thrown and nothing changes")
    func unknownEvent() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))

        await #expect(throws: ProgressError.unknownEvent) {
            try await DefaultDeleteEventUseCase(progressRepository: repository, photoStore: photos).execute(eventID: UUID())
        }
        #expect(try await repository.fetchEvents().count == 1)
    }

    @Test("Given an id that is not a moment, when updating, then unknownMoment is thrown")
    func unknownMoment() async throws {
        try await repository.add(ProgressEvent(kind: .quest(id: "q1"), childID: UUID(), date: today))
        await #expect(throws: MomentError.unknownMoment) {
            try await DefaultUpdateMomentUseCase(progressRepository: repository, photoStore: photos)
                .execute(momentID: UUID(), happenedOn: today, note: nil, photo: .keep, now: today)
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
    func add(_ event: ProgressEvent) async throws { throw Failure() }
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool { throw Failure() }
    func update(_ event: ProgressEvent) async throws { throw Failure() }
    func delete(id: UUID) async throws { throw Failure() }
}

/// Keeps "photos" in memory, exactly as given.
actor SpyPhotoStore: PhotoStore {
    private(set) var stored: [String: Data] = [:]
    /// Every photo ever written, kept or not.
    private(set) var saveCount = 0

    func save(_ imageData: Data) async throws -> String {
        saveCount += 1
        let id = UUID().uuidString
        stored[id] = imageData
        return id
    }

    /// Tags the data so tests can tell a thumbnail from the original.
    func thumbnail(id: String, maxPixelSize: Int) async -> Data? {
        stored[id].map { Data("thumb\(maxPixelSize):".utf8) + $0 }
    }

    func delete(id: String) async {
        stored[id] = nil
    }

    func deleteAll() async {
        stored = [:]
    }
}

@Suite("GetTimelineUseCase")
struct GetTimelineUseCaseTests {
    @Test("Given stored events, when executing, then the timeline is built from them and the catalog")
    func buildsTimeline() async throws {
        let repository = SpyProgressRepository()
        let quest = try #require(Stub.catalog.quests.first)
        try await repository.add(ProgressEvent(kind: .quest(id: quest.id), childID: UUID(), date: .now))
        let sut = DefaultGetTimelineUseCase(
            contentRepository: StubContentRepository(result: .success(Stub.catalog)),
            progressRepository: repository
        )

        let entries = try await sut.execute()

        #expect(entries.map(\.xp) == [quest.xp])
    }
}
