import Application
import Domain
import Foundation

/// An in-memory stand-in for both progress use cases, backed by the stub catalog.
actor FakeProgress: CompleteQuestUseCase, DefeatBossUseCase, CaptureMomentUseCase,
    UpdateMomentUseCase, DeleteEventUseCase, UndoRecordUseCase, GetPhotoUseCase, MarkTitleSeenUseCase {
    private(set) var events: [ProgressEvent] = []
    /// What the store keeps for titles, kept as the app does (ADR-0055 §3): the title before a deletion only.
    private(set) var kept = KeptStanding()

    /// The dad's standing by the app's own rules, from the log and the kept record.
    private var standing: DadStanding {
        DadStanding(progress: DadProgress(events: events, catalog: HeroStub.catalog), catalog: HeroStub.catalog, kept: kept)
    }

    private var failsToMarkSeen = false

    /// Closing a title card can't be saved from now on, as if the store couldn't be written.
    func failMarkingSeen() {
        failsToMarkSeen = true
    }

    func execute(titleID: String) async throws {
        if failsToMarkSeen { throw StubError.boom }
        kept.seenTitleID = titleID
    }
    private var shouldFail = false

    func seed(times: Int) {
        events = (0..<times).map { _ in
            ProgressEvent(kind: .quest(id: "q1"), childID: HeroStub.niko.id, date: HeroStub.today)
        }
    }

    func failNext() {
        shouldFail = true
    }

    private var isSlow = false
    private var slowSaveReleased = false
    private var slowSave: CheckedContinuation<Void, Never>?

    /// The next quest, moment or undo waits to save, like a slow disk, until `finishSlowSave()`.
    func slowNext() {
        isSlow = true
        slowSaveReleased = false
    }

    /// Lets the save `slowNext()` held go on.
    func finishSlowSave() {
        slowSaveReleased = true
        slowSave?.resume()
        slowSave = nil
    }

    private func waitIfSlow() async {
        guard isSlow else { return }
        isSlow = false
        guard !slowSaveReleased else { return }
        await withCheckedContinuation { slowSave = $0 }
    }

    /// Home's overview loads wait, each until released, so two loads can be made to finish in a chosen order.
    private var holdsOverviews = false
    /// A waiting load has already read the log, as a slow read would: released late, it shows what was true then.
    private var readsBeforeHolding = false
    private var heldOverviews: [CheckedContinuation<Void, Never>] = []
    private var heldWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func holdOverviews(afterReading: Bool = false) {
        holdsOverviews = true
        readsBeforeHolding = afterReading
    }

    /// Returns once `count` overview loads are waiting.
    func waitUntilHeld(_ count: Int) async {
        guard heldOverviews.count < count else { return }
        await withCheckedContinuation { heldWaiters.append((count, $0)) }
    }

    var heldOverviewCount: Int { heldOverviews.count }

    /// The oldest waiting load goes on.
    func releaseOldestOverview() {
        guard !heldOverviews.isEmpty else { return }
        heldOverviews.removeFirst().resume()
    }

    /// The newest waiting load goes on, ahead of the older ones.
    func releaseNewestOverview() {
        guard !heldOverviews.isEmpty else { return }
        heldOverviews.removeLast().resume()
    }

    /// Every waiting load goes on, and later ones no longer wait.
    func releaseAllOverviews() {
        holdsOverviews = false
        heldOverviews.forEach { $0.resume() }
        heldOverviews = []
    }

    private func waitIfHeld() async {
        guard holdsOverviews else { return }
        await withCheckedContinuation { continuation in
            heldOverviews.append(continuation)
            let ready = heldWaiters.filter { $0.count <= heldOverviews.count }
            heldWaiters.removeAll { $0.count <= heldOverviews.count }
            ready.forEach { $0.continuation.resume() }
        }
    }

    /// Set while home's overview shows an older log, as if reloading it failed.
    private var frozen: [ProgressEvent]?
    func freezeOverview() {
        frozen = events
    }

    /// The log as the dad's progress, read against the hero stub catalog.
    var current: DadProgress {
        DadProgress(events: frozen ?? events, catalog: HeroStub.catalog)
    }

    /// Home's overview fails to load from now on, as if the store could no longer be read.
    private var overviewFails = false
    func failOverview() {
        overviewFails = true
    }

    /// Home's overview can be read again.
    func mendOverview() {
        overviewFails = false
    }

    /// The family's captured firsts in the log, read against the hero stub catalog.
    var currentMoments: FamilyMoments {
        FamilyMoments(events: frozen ?? events, catalog: HeroStub.catalog)
    }

    /// The dad's progress and the family's moments home's overview reads, or an error once `failOverview()` was called.
    func overviewLog() async throws -> (progress: DadProgress, moments: FamilyMoments) {
        let early = readsBeforeHolding ? (current, currentMoments) : nil
        await waitIfHeld()
        if overviewFails { throw StubError.boom }
        return early ?? (current, currentMoments)
    }

    /// The photos each quest or boss was recorded with.
    private(set) var recordedPhotos: [[Data]] = []

    func execute(questID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        await waitIfSlow()
        recordedPhotos.append(journal.photos)
        return try record(.quest(id: questID), childID: childID, on: date, note: journal.note)
    }

    func execute(bossID: String, childID: UUID, on date: Date, journal: JournalInput) async throws -> ProgressChange {
        recordedPhotos.append(journal.photos)
        return try record(.boss(id: bossID), childID: childID, on: date, note: journal.note)
    }

    private var photos: [String: Data] = [:]

    func execute(_ request: CaptureMomentRequest, now: Date) async throws -> ProgressChange {
        await waitIfSlow()
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        let event = ProgressEvent(kind: .first(id: request.firstID), childID: request.childID, date: request.date)
        events.append(event)
        let moment = FamilyMoments(events: events, catalog: HeroStub.catalog)
            .moments(for: request.childID).first { $0.eventID == event.id }
        return ProgressChange(
            before: before, after: DadProgress(events: events, catalog: HeroStub.catalog), eventID: event.id,
            moment: moment
        )
    }

    func execute(momentID: UUID, happenedOn date: Date, note: String?, photos: [EntryPhoto], now: Date) async throws {
        if shouldFail { throw StubError.boom }
        guard let index = events.firstIndex(where: { $0.id == momentID }) else { return }
        let old = events[index]
        let photoIDs = photos.map { photo in
            switch photo {
            case .kept(let id): id
            case .added(let data): store(data)
            }
        }
        events[index] = ProgressEvent(
            id: old.id, kind: old.kind, childID: old.childID, date: date, note: note, photoIDs: photoIDs
        )
    }

    /// A moment of the first `HeroStub.niko` can capture, already holding these photos, captured by the dad unless
    /// another author is named.
    func seedMoment(photos: [Data], by authorID: UUID = .testDad) {
        events.append(ProgressEvent(
            authorID: authorID, kind: .first(id: "f1"), childID: HeroStub.niko.id, date: HeroStub.today,
            photoIDs: photos.map(store)
        ))
    }

    private func store(_ data: Data) -> String {
        let id = "photo-\(self.photos.count + 1)"
        self.photos[id] = data
        return id
    }

    /// A deletion: what the dad holds is kept first, so his title stays.
    func execute(eventID: UUID) async throws {
        if shouldFail { throw StubError.boom }
        if let title = standing.titleToKeep { kept.titleID = title.id }
        events.removeAll { $0.id == eventID }
    }

    /// Undo: the entry goes and nothing is kept for it; a card closed above the title still held goes back to it.
    func execute(undoing eventID: UUID) async throws -> DadTitle? {
        await waitIfSlow()
        if shouldFail { throw StubError.boom }
        guard events.contains(where: { $0.id == eventID }) else { throw ProgressError.unknownEvent }
        events.removeAll { $0.id == eventID }
        if let seen = standing.seenAfterUndo { kept.seenTitleID = seen.id }
        return standing.title
    }

    func execute(id: String, maxPixelSize: Int) async -> Data? {
        photos[id]
    }

    var recordedChildIDs: [UUID] { events.map(\.childID) }
    var eventCount: Int { events.count }

    private func record(_ kind: ProgressEvent.Kind, childID: UUID, on date: Date, note: String?) throws -> ProgressChange {
        if shouldFail { throw StubError.boom }
        let before = DadProgress(events: events, catalog: HeroStub.catalog)
        let event = ProgressEvent(kind: kind, childID: childID, date: date, note: note)
        events.append(event)
        return ProgressChange(before: before, after: DadProgress(events: events, catalog: HeroStub.catalog), eventID: event.id)
    }
}
