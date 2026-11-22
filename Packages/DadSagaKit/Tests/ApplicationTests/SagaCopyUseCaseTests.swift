import Application
import Domain
import Foundation
import Testing

/// Exporting the saga to a file and importing one in its place (ADR-0057 §6, §7), against doubles for the store and the
/// file. The file format itself is tested in Data.
@Suite("Exporting and importing the saga")
struct SagaCopyUseCaseTests {
    let lena = Child(name: "Λένα", birthDay: .day(2023, 11, 14))
    let today = Date(timeIntervalSince1970: 1_790_000_000)

    private func saga(_ child: Child, photos: [[String]]) -> StoredSaga {
        StoredSaga(
            profile: PlayerProfile(children: [child], heroClassID: "h-chef"),
            events: photos.enumerated().map { index, ids in
                ProgressEvent(kind: .quest(id: "q\(index)"), childID: child.id, date: today, photoIDs: ids)
            },
            outfit: Outfit(choices: [.play: .hidden]),
            kept: KeptStanding(titleID: "t-rookie")
        )
    }

    // MARK: Exporting

    @Test("Given a saga and answered film offers, when exporting, then the file gets them with every stored photo")
    func exportWritesTheSaga() async throws {
        let photos = SpyPhotoStore()
        let first = try await photos.save(Data("one".utf8))
        let second = try await photos.save(Data("two".utf8))
        let stored = saga(lena, photos: [[first, second]])
        let offers = FakeSagaOffers()
        await offers.markAnswered("lena/birthday/1")
        let files = ScriptedCopyFiles()
        let sut = DefaultMakeSagaCopyUseCase(
            wholeSaga: MemorySaga(stored), sagaOffers: offers, photoStore: photos, files: files
        )

        let made = try await sut.execute(on: today) { _ in }

        #expect(made.byteCount == 6)
        #expect(await files.written == SagaCopy(saga: stored, answeredOccasionIDs: ["lena/birthday/1"], madeAt: today))
        #expect(await files.photoBytes == [Data("one".utf8), Data("two".utf8)])
    }

    @Test("Given an entry whose photo file is gone, when exporting, then the entry goes without it")
    func exportSkipsMissingPhotos() async throws {
        let photos = SpyPhotoStore()
        let kept = try await photos.save(Data("kept".utf8))
        let files = ScriptedCopyFiles()
        let sut = DefaultMakeSagaCopyUseCase(
            wholeSaga: MemorySaga(saga(lena, photos: [["gone", kept]])), sagaOffers: FakeSagaOffers(), photoStore: photos,
            files: files
        )

        _ = try await sut.execute(on: today) { _ in }

        #expect(await files.written?.saga.events.map(\.photoIDs) == [[kept]])
    }

    @Test("Given no saga yet, when exporting, then there is nothing to export")
    func exportWithoutSaga() async {
        let sut = DefaultMakeSagaCopyUseCase(
            wholeSaga: MemorySaga(nil), sagaOffers: FakeSagaOffers(), photoStore: SpyPhotoStore(), files: ScriptedCopyFiles()
        )

        await #expect(throws: SagaCopyError.nothingToCopy) { try await sut.execute(on: today) { _ in } }
    }

    @Test("Given a disk that fills up while writing, when exporting, then it says there isn't enough space")
    func exportOnAFullDisk() async {
        let files = ScriptedCopyFiles(writeFails: CocoaError(.fileWriteOutOfSpace))
        let sut = DefaultMakeSagaCopyUseCase(
            wholeSaga: MemorySaga(saga(lena, photos: [])), sagaOffers: FakeSagaOffers(), photoStore: SpyPhotoStore(),
            files: files
        )

        await #expect(throws: SagaCopyError.notEnoughSpace) { try await sut.execute(on: today) { _ in } }
    }

    // MARK: Importing

    private struct Restore {
        let sut: DefaultRestoreSagaUseCase
        let store: MemorySaga
        let photos: SpyPhotoStore
        let offers: FakeSagaOffers
        let scheduler: FakeNotificationScheduler
        let schedule: CountingSchedule
    }

    /// A phone with Λένα's saga and one photo, about to import a copy of Νίκος's with two photos.
    private func restore(reading files: ScriptedCopyFiles, replaceFails: Bool = false) async throws -> Restore {
        let photos = SpyPhotoStore()
        let old = try await photos.save(Data("old".utf8))
        let store = MemorySaga(saga(lena, photos: [[old]]), replaceFails: replaceFails)
        let offers = FakeSagaOffers()
        await offers.markAnswered("lena/birthday/1")
        let scheduler = FakeNotificationScheduler(status: .allowed)
        let shown = DateComponents(year: 2026, month: 12, day: 1, hour: 9)
        await scheduler.deliver(PendingReminder(time: shown, title: "Λένα", body: "", link: .child(lena.id)))
        let schedule = CountingSchedule()
        let sut = DefaultRestoreSagaUseCase(
            wholeSaga: store, progressRepository: store, photoStore: photos, sagaOffers: offers, files: files,
            schedule: schedule, notificationScheduler: scheduler
        )
        return Restore(sut: sut, store: store, photos: photos, offers: offers, scheduler: scheduler, schedule: schedule)
    }

    private let nikos = Child(name: "Νίκος", birthDay: .day(2024, 2, 1))

    private var nikosCopy: SagaCopy {
        SagaCopy(saga: saga(nikos, photos: [["p1", "p2"]]), answeredOccasionIDs: ["nikos/world/w1"], madeAt: today)
    }

    @Test("Given a copy, when opening it, then its photos are stored and it waits, showing whose it is, with nothing replaced")
    func openingStoresPhotosAndWaits() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]))

        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }

        #expect(opened.childNames == ["Νίκος"])
        #expect(opened.madeAt == today)
        #expect(await restore.photos.stored.count == 3)
        #expect(await restore.store.saga?.profile.children == [lena])
    }

    @Test("Given an opened copy, when the dad confirms, then it replaces the saga, its photos and its film answers")
    func confirmingReplacesTheSaga() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]))
        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }

        try await restore.sut.restore(opened, on: today)

        let restored = try #require(await restore.store.saga)
        #expect(restored.profile.children == [nikos])
        let photoIDs = restored.photoIDs
        #expect(Set(await restore.photos.stored.keys) == Set(photoIDs))
        #expect(try await photoIDs.asyncMap { try await restore.photos.storedData(id: $0) } == [Data("a".utf8), Data("b".utf8)])
        #expect(await restore.offers.answeredOccasionIDs() == ["nikos/world/w1"])
        #expect(await restore.schedule.runs == 1)
        #expect(await restore.scheduler.delivered.isEmpty)
    }

    @Test("Given a file that fails half way, when opening it, then every photo it stored is gone and the saga is untouched")
    func failedOpenLeavesNothing() async throws {
        let files = ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"], failsAfter: 1, with: SagaCopyError.incomplete)
        let restore = try await restore(reading: files)

        await #expect(throws: SagaCopyError.incomplete) {
            try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }
        }

        #expect(await restore.photos.stored.count == 1)
        #expect(await restore.store.replaceCount == 0)
        #expect(await restore.offers.answeredOccasionIDs() == ["lena/birthday/1"])
    }

    @Test("Given an import being cancelled, when opening, then it stops, says cancelled and keeps no photo")
    func cancelledOpenLeavesNothing() async throws {
        let files = ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"], failsAfter: 1, with: CancellationError())
        let restore = try await restore(reading: files)

        await #expect(throws: CancellationError.self) {
            try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }
        }

        #expect(await restore.photos.stored.count == 1)
    }

    @Test("Given a replace that fails, when the dad confirms, then the old saga, photos, offers and notes stay")
    func failedReplaceChangesNothing() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]), replaceFails: true)
        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }
        let before = await restore.store.saga

        await #expect(throws: SagaCopyError.failed) { try await restore.sut.restore(opened, on: today) }

        #expect(await restore.store.saga == before)
        #expect(await restore.photos.stored.values.map { $0 } == [Data("old".utf8)])
        #expect(await restore.offers.answeredOccasionIDs() == ["lena/birthday/1"])
        #expect(await restore.schedule.runs == 0)
        #expect(await restore.scheduler.delivered.count == 1)
    }

    @Test("Given a restored copy, when it is discarded afterwards, then the saga keeps its photos")
    func discardAfterRestoreKeepsThePhotos() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]))
        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }
        try await restore.sut.restore(opened, on: today)

        await restore.sut.discard(opened)

        let photoIDs = try #require(await restore.store.saga?.photoIDs)
        #expect(Set(await restore.photos.stored.keys) == Set(photoIDs))
    }

    @Test("Given a discarded copy, when the dad confirms it anyway, then it is refused and the saga stays")
    func restoreAfterDiscardIsRefused() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]))
        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }
        await restore.sut.discard(opened)

        await #expect(throws: SagaCopyError.failed) { try await restore.sut.restore(opened, on: today) }

        #expect(await restore.store.saga?.profile.children == [lena])
        #expect(await restore.photos.stored.values.map { $0 } == [Data("old".utf8)])
    }

    @Test("Given a store holding two children with one id, when exporting, then no copy is written that couldn't come back")
    func exportRefusesWhatImportWould() async {
        let files = ScriptedCopyFiles()
        var broken = saga(lena, photos: [])
        broken.profile.children.append(lena)
        let sut = DefaultMakeSagaCopyUseCase(
            wholeSaga: MemorySaga(broken), sagaOffers: FakeSagaOffers(), photoStore: SpyPhotoStore(), files: files
        )

        await #expect(throws: SagaCopyError.failed) { try await sut.execute(on: today) { _ in } }
        #expect(await files.written == nil)
    }

    @Test("Given an opened copy, when the dad says no, then its photos go and nothing else changes")
    func discardingKeepsTheSaga() async throws {
        let restore = try await restore(reading: ScriptedCopyFiles(reading: nikosCopy, photos: ["a", "b"]))
        let opened = try await restore.sut.open(fileAt: URL(filePath: "/picked.dadsaga")) { _ in }

        await restore.sut.discard(opened)

        #expect(await restore.photos.stored.values.map { $0 } == [Data("old".utf8)])
        #expect(await restore.store.saga?.profile.children == [lena])
    }
}

// MARK: - Doubles

/// The saga in memory, as the store would keep it.
actor MemorySaga: WholeSagaRepository, ProgressRepository {
    struct Failure: Error {}
    private(set) var saga: StoredSaga?
    private(set) var replaceCount = 0
    private let replaceFails: Bool

    init(_ saga: StoredSaga?, replaceFails: Bool = false) {
        self.saga = saga
        self.replaceFails = replaceFails
    }

    func readAll() async throws -> StoredSaga? { saga }

    func replaceAll(with saga: StoredSaga) async throws {
        if replaceFails { throw Failure() }
        replaceCount += 1
        self.saga = saga
    }

    func eraseAll() async throws { saga = nil }

    func fetchEvents() async throws -> [ProgressEvent] { saga?.events ?? [] }
    func referencedPhotoIDs() async throws -> Set<String> { Set(saga?.photoIDs ?? []) }
    func add(_ event: ProgressEvent) async throws {}
    func addUnlessRecorded(_ event: ProgressEvent) async throws -> Bool { false }
    func update(_ event: ProgressEvent) async throws {}
    func delete(id: UUID) async throws {}
}

/// A file that holds `copy` and hands out `photos` in order, maybe failing after some of them.
actor ScriptedCopyFiles: SagaCopyFiles {
    private(set) var written: SagaCopy?
    private(set) var photoBytes: [Data] = []
    private let writeFails: (any Error)?
    private let copy: SagaCopy?
    private let photos: [String]
    private let failsAfter: Int?
    private let failure: any Error

    init(
        writeFails: (any Error)? = nil,
        reading copy: SagaCopy? = nil,
        photos: [String] = [],
        failsAfter: Int? = nil,
        with failure: any Error = SagaCopyError.damaged
    ) {
        self.writeFails = writeFails
        self.copy = copy
        self.photos = photos
        self.failsAfter = failsAfter
        self.failure = failure
    }

    func write(
        _ copy: SagaCopy,
        photo: @escaping @Sendable (String) async throws -> Data,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> MadeSagaCopy {
        if let writeFails { throw writeFails }
        written = copy
        for id in copy.saga.photoIDs {
            photoBytes.append(try await photo(id))
        }
        return MadeSagaCopy(url: URL(filePath: "/tmp/copy.dadsaga"), byteCount: Int64(photoBytes.reduce(0) { $0 + $1.count }))
    }

    func read(
        fileAt url: URL,
        adopt: @escaping @Sendable (Data) async throws -> String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> SagaCopy {
        guard let copy else { throw SagaCopyError.notACopy }
        var newIDs: [String: String] = [:]
        for (index, (id, bytes)) in zip(copy.saga.photoIDs, photos).enumerated() {
            if index == failsAfter { throw failure }
            newIDs[id] = try await adopt(Data(bytes.utf8))
        }
        var restored = copy
        restored.saga = copy.saga.replacingPhotoIDs(newIDs)
        return restored
    }

    func discardTemporaryFiles() async {}
}

actor CountingSchedule: ScheduleWeeklyRemindersUseCase {
    private(set) var runs = 0
    func execute(on date: Date) async { runs += 1 }
}

extension FakeNotificationScheduler {
    func deliver(_ reminder: PendingReminder) {
        delivered.append(reminder)
    }
}

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        for element in self { result.append(try await transform(element)) }
        return result
    }
}
