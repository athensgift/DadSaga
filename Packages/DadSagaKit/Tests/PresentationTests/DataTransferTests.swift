import Application
import Domain
import Foundation
import Testing
@testable import Presentation

/// Settings › Export and import and onboarding's Import data (ADR-0057 §8), as the dad sees them.
@MainActor
@Suite("Exporting and importing data on screen")
struct DataTransferTests {
    let made = Date(timeIntervalSince1970: 1_790_000_000)

    func importer(
        _ restore: FakeRestore,
        replacesSaga: Bool = true,
        backgroundTime: any BackgroundTime = ImmediateBackgroundTime(),
        locale: String = "en_US",
        onImported: @escaping @MainActor () -> Void = {}
    ) -> DataImportViewModel {
        DataImportViewModel(
            restore: restore, backgroundTime: backgroundTime, replacesSaga: replacesSaga,
            onImported: onImported, locale: Locale(identifier: locale), now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    private func exporter(_ makeCopy: FakeMakeCopy, backgroundTime: any BackgroundTime = ImmediateBackgroundTime(),
                          locale: String = "en_US") -> DataExportViewModel {
        DataExportViewModel(
            makeCopy: makeCopy, backgroundTime: backgroundTime, importer: importer(FakeRestore(copy: nil)),
            locale: Locale(identifier: locale), now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    func copy(names: [String]) -> OpenedSagaCopy {
        let children = names.map { Child(name: $0, birthDay: nil) }
        return OpenedSagaCopy(
            copy: SagaCopy(
                saga: StoredSaga(profile: PlayerProfile(children: children, heroClassID: "h-chef"), events: [],
                                 outfit: Outfit(), kept: KeptStanding()),
                answeredOccasionIDs: [], madeAt: made
            ),
            adoptedPhotoIDs: ["p1"]
        )
    }

    // MARK: Exporting

    @Test("Given a saga, when the dad exports it, then the page offers the file with its size")
    func exportShowsTheFile() async {
        let file = MadeSagaCopy(url: URL(filePath: "/tmp/a.dadsaga"), byteCount: 2_500_000)
        let sut = exporter(FakeMakeCopy(result: .success(file)))

        await sut.export()

        guard case .exported(let exported) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(exported.readyLine == "Your copy is ready · 2.5 MB")
        #expect(!sut.isWorking)
    }

    @Test("Given Greek, when the copy is ready, then the size reads in Greek")
    func exportSizeInGreek() async {
        let sut = exporter(
            FakeMakeCopy(result: .success(MadeSagaCopy(url: URL(filePath: "/tmp/a.dadsaga"), byteCount: 2_500_000))),
            locale: "el_GR"
        )

        await sut.export()

        guard case .exported(let exported) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(exported.readyLine == "Το αντίγραφό σου είναι έτοιμο · 2,5 MB")
    }

    @Test("Given a full disk, when exporting, then the page says to free up space, and that the saga hasn't changed")
    func exportOnAFullDisk() async {
        let sut = exporter(FakeMakeCopy(result: .failure(SagaCopyError.notEnoughSpace)))

        await sut.export()

        #expect(sut.state == .failed(
            "There isn't enough free space on this iPhone. Free up some space and try again. Your saga hasn't changed."
        ))
    }

    @Test("Given the dad leaving the app too long, when exporting, then the page says it stopped and to keep DadSaga open")
    func exportLeftTheApp() async {
        let sut = exporter(FakeMakeCopy(result: .success(MadeSagaCopy(url: URL(filePath: "/a"), byteCount: 1))),
                           backgroundTime: ExpiringBackgroundTime())

        await sut.export()

        guard case .failed(let message) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(message.hasPrefix("The export stopped when you left DadSaga."))
    }

    @Test("Given an export under way, when the dad cancels, then the page is back as it was and nothing is offered")
    func exportCancel() async {
        let slow = FakeMakeCopy(result: .success(MadeSagaCopy(url: URL(filePath: "/a"), byteCount: 1)), waits: true)
        let sut = exporter(slow)

        let export = Task { await sut.export() }
        await slow.started()
        #expect(sut.isWorking)
        sut.cancel()
        await export.value

        #expect(sut.state == .ready)
        #expect(!sut.isWorking)
    }

    // MARK: Importing

    @Test("Given a whole copy, when the dad picks it in Settings, then he is asked, with its date, names and what goes")
    func importAsks() async {
        let restore = FakeRestore(copy: copy(names: ["Lena", "Nikos"]))
        let sut = importer(restore)

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        guard case .asking(let question) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(question.title == "Import this copy?")
        #expect(question.message.hasPrefix("Made on "))
        #expect(question.message.contains("Lena and Nikos"))
        #expect(question.message.contains("This can't be undone."))
        #expect(question.confirmIsDestructive)
        #expect(await restore.restored.isEmpty)
    }

    @Test("Given onboarding, when the dad picks a copy, then the question doesn't speak of replacing anything")
    func importOnOnboardingAsksPlainly() async {
        let sut = importer(FakeRestore(copy: copy(names: ["Lena"])), replacesSaga: false)

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        guard case .asking(let question) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(!question.message.contains("replaced"))
        #expect(!question.confirmIsDestructive)
    }

    @Test("Given the question, when the dad says yes, then the copy is imported and the root is told")
    func importConfirmed() async {
        let restore = FakeRestore(copy: copy(names: ["Lena"]))
        var imported = 0
        let sut = importer(restore) { imported += 1 }
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.confirm()

        #expect(await restore.restored.count == 1)
        #expect(imported == 1)
        #expect(sut.state == .ready)
    }

    @Test("Given the question, when the dad says no, then what was read goes and nothing is imported")
    func importDeclined() async {
        let restore = FakeRestore(copy: copy(names: ["Lena"]))
        var imported = 0
        let sut = importer(restore) { imported += 1 }
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.decline()

        #expect(await restore.discarded.count == 1)
        #expect(await restore.restored.isEmpty)
        #expect(imported == 0)
        #expect(sut.state == .ready)
    }

    @Test("Given a newer copy in Settings, when the dad picks it, then he's told to update and that his saga hasn't changed")
    func importNewerFormat() async {
        let sut = importer(FakeRestore(copy: nil, failure: SagaCopyError.newerFormat))

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        #expect(sut.state == .failed(
            "This copy was made by a newer version of DadSaga. Update the app, then try again. Your saga hasn't changed."
        ))
    }

    @Test("Given onboarding, when a file isn't whole, then the message doesn't speak of a saga that isn't there yet")
    func importDamagedOnOnboarding() async {
        let sut = importer(FakeRestore(copy: nil, failure: SagaCopyError.incomplete), replacesSaga: false)

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        #expect(sut.state == .failed(
            "This file isn't a complete DadSaga copy. It may not have finished saving or sending."
        ))
    }

    @Test("Given a file not whole, not a copy, or damaged, when picked, then each reads the same message")
    func notWholeFilesShareAMessage() async {
        var messages: Set<String> = []
        for error in [SagaCopyError.notACopy, .incomplete, .damaged] {
            let sut = importer(FakeRestore(copy: nil, failure: error))
            await sut.picked(URL(filePath: "/picked.dadsaga"))
            if case .failed(let message) = sut.state { messages.insert(message) }
        }

        #expect(messages.count == 1)
    }

    @Test("Given an unanswered question, when the page closes, then what was read is let go")
    func closingDiscards() async {
        let restore = FakeRestore(copy: copy(names: ["Lena"]))
        let sut = importer(restore)
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.closed()

        #expect(await restore.discarded.count == 1)
        #expect(sut.state == .ready)
    }

    @Test("Given an import being read, when the page reports work, then exporting is held until it ends")
    func exportWaitsForImport() async {
        let restore = FakeRestore(copy: copy(names: ["Lena"]), waits: true)
        let importer = importer(restore)
        let sut = DataExportViewModel(
            makeCopy: FakeMakeCopy(result: .success(MadeSagaCopy(url: URL(filePath: "/a"), byteCount: 1))),
            backgroundTime: ImmediateBackgroundTime(), importer: importer, locale: Locale(identifier: "en_US")
        )

        let reading = Task { await importer.picked(URL(filePath: "/picked.dadsaga")) }
        await restore.started()
        #expect(sut.isWorking)
        await sut.export()
        #expect(sut.state == .ready)
        importer.cancel()
        await reading.value
        #expect(!sut.isWorking)
        #expect(importer.state == .ready)
        #expect(await restore.restored.isEmpty)
    }

    @Test("Given a commit that fails in Settings, when the dad confirms, then he's told his saga hasn't changed")
    func failedCommitInSettings() async {
        var imported = 0
        let sut = importer(FakeRestore(copy: copy(names: ["Lena"]), restoreFailure: SagaCopyError.failed)) { imported += 1 }
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.confirm()

        #expect(sut.state == .failed("Couldn't import the data. Please try again. Your saga hasn't changed."))
        #expect(imported == 0)
    }

    @Test("Given a commit that fails on onboarding, when the dad confirms, then the message has no saga to speak of")
    func failedCommitOnOnboarding() async {
        let sut = importer(FakeRestore(copy: copy(names: ["Lena"]), restoreFailure: SagaCopyError.failed),
                           replacesSaga: false)
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.confirm()

        #expect(sut.state == .failed("Couldn't import the data. Please try again."))
    }

    @Test("Given each way opening can fail in Settings, when picked, then it says what to do and that nothing changed",
          arguments: [
            (SagaCopyError.unreadable as any Error & Sendable,
             "The file couldn't be opened. If it's in iCloud Drive or another cloud service, check your connection "
                + "and try again."),
            (SagaCopyError.notEnoughSpace, "There isn't enough free space on this iPhone. Free up some space and try again."),
            (CocoaError(.fileReadUnknown), "Couldn't import the data. Please try again.")
          ])
    func importMessages(failure: any Error & Sendable, reason: String) async {
        let sut = importer(FakeRestore(copy: nil, failure: failure))

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        #expect(sut.state == .failed(reason + " Your saga hasn't changed."))
    }

    @Test("Given the dad leaving the app too long, when importing, then the page says it stopped and to keep DadSaga open")
    func importLeftTheApp() async {
        let sut = importer(FakeRestore(copy: copy(names: ["Lena"])), backgroundTime: ExpiringBackgroundTime())

        await sut.picked(URL(filePath: "/picked.dadsaga"))

        guard case .failed(let message) = sut.state else { Issue.record("\(sut.state)"); return }
        #expect(message.hasPrefix("The import stopped when you left DadSaga."))
        #expect(message.hasSuffix("Your saga hasn't changed."))
    }

    @Test("Given no saga or another failure, when exporting, then the page says so calmly",
          arguments: [
            (SagaCopyError.nothingToCopy as any Error & Sendable, "There's nothing to export yet."),
            (CocoaError(.fileWriteUnknown), "Couldn't export your data. Please try again.")
          ])
    func exportMessages(failure: any Error & Sendable, reason: String) async {
        let sut = exporter(FakeMakeCopy(result: .failure(failure)))

        await sut.export()

        #expect(sut.state == .failed(reason + " Your saga hasn't changed."))
    }

    // MARK: The root

    @Test("Given home, when a saga is imported from Settings, then home is built anew on Adventure and links wait no more")
    func rootRebuildsHome() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: HeroStub.profile), getPreferences: StubGetPreferences())
        await sut.onAppear()
        sut.selectedTab = .timeline
        sut.unsavedWork.set(UUID(), in: UnsavedScope.settings, hasUnsavedChanges: true)
        sut.open(url: AppLink.child(HeroStub.niko.id).url)
        let generation = sut.sagaGeneration

        sut.sagaImported()

        #expect(!sut.unsavedWork.isHeld)
        #expect(sut.sagaGeneration == generation + 1)
        #expect(sut.selectedTab == .adventure)
        #expect(sut.pendingLink == nil)
        #expect(sut.state == .home)
    }

    @Test("Given onboarding, when a saga is imported, then home opens")
    func rootOpensHomeFromOnboarding() async {
        let sut = RootViewModel(getProfile: StubGetProfile(profile: nil), getPreferences: StubGetPreferences())
        await sut.onAppear()

        sut.sagaImported()

        #expect(sut.state == .home)
    }
}
