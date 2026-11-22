import Application
import Foundation
import Localization
import Observation

/// Presenter for importing an exported saga (ADR-0057 §7): the dad picks a file, the whole file is read and checked,
/// he is asked, and only then does it take the place of the saga on this iPhone. In Settings and on onboarding's first
/// step.
@MainActor
@Observable
public final class DataImportViewModel: Identifiable {
    public enum State: Equatable {
        case ready
        /// Reading and checking the file; the fraction done.
        case opening(Double)
        /// The file is whole: waiting for the dad's answer.
        case asking(DataImportQuestion)
        case importing
        case failed(String)
    }

    public let content: DataImportContent
    public private(set) var state: State = .ready
    /// The file picker is on screen.
    public var isPicking = false

    /// Opening or importing: the screen can't be closed, and a link from outside waits (ADR-0050 §4).
    public var isWorking: Bool {
        switch state {
        case .opening, .importing: true
        case .ready, .asking, .failed: false
        }
    }

    private let restore: any RestoreSagaUseCase
    private let backgroundTime: any BackgroundTime
    private let replacesSaga: Bool
    private let onImported: @MainActor () -> Void
    private let locale: Locale
    private let now: @Sendable () -> Date
    private var opened: OpenedSagaCopy?
    private var opening: Task<OpenedSagaCopy, any Error>?
    private var strings: Strings { Strings(locale: locale) }

    /// - Parameters:
    ///   - replacesSaga: there is a saga on this iPhone that the import takes the place of; `false` on onboarding.
    ///   - onImported: the saga on this iPhone is now the imported one.
    public init(
        restore: any RestoreSagaUseCase,
        backgroundTime: any BackgroundTime,
        replacesSaga: Bool,
        onImported: @escaping @MainActor () -> Void,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.restore = restore
        self.backgroundTime = backgroundTime
        self.replacesSaga = replacesSaga
        self.onImported = onImported
        self.locale = locale
        self.now = now
        content = DataImportContent.make(strings: Strings(locale: locale), replacesSaga: replacesSaga)
    }

    public func pick() {
        guard !isWorking else { return }
        isPicking = true
    }

    /// The file the dad picked, read and checked whole before he is asked anything.
    public func picked(_ url: URL) async {
        guard !isWorking else { return }
        await discardOpened()
        state = .opening(0)
        let (fractions, progress) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        let showing = Task { [weak self] in
            for await fraction in fractions where self?.isOpening == true { self?.state = .opening(fraction) }
        }
        let restore = restore
        let work = Task { [backgroundTime] in
            try await backgroundTime.run("Import data") {
                try await restore.open(fileAt: url) { progress.yield($0) }
            }
        }
        opening = work
        defer {
            progress.finish()
            showing.cancel()
            opening = nil
        }
        do {
            let copy = try await work.value
            opened = copy
            state = .asking(question(for: copy))
        } catch {
            state = failure(error)
        }
    }

    /// Stops reading the file; nothing on this iPhone changed.
    public func cancel() {
        opening?.cancel()
    }

    /// The dad said yes: the saga on this iPhone becomes the file's.
    public func confirm() async {
        guard case .asking = state, let opened else { return }
        self.opened = nil
        state = .importing
        let restore = restore
        let date = now()
        do {
            try await backgroundTime.run("Import data") { try await restore.restore(opened, on: date) }
            state = .ready
            onImported()
        } catch {
            state = failure(error)
        }
    }

    /// The dad said no: what was read from the file goes, and nothing changed.
    public func decline() async {
        guard case .asking = state else { return }
        state = .ready
        await discardOpened()
    }

    /// The screen closed: a file read but never answered is let go.
    public func closed() async {
        if case .asking = state { state = .ready }
        await discardOpened()
    }

    private var isOpening: Bool {
        if case .opening = state { true } else { false }
    }

    private func discardOpened() async {
        guard let opened else { return }
        self.opened = nil
        await restore.discard(opened)
    }

    private func question(for copy: OpenedSagaCopy) -> DataImportQuestion {
        let strings = strings
        let made = copy.madeAt.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(locale))
        let names = copy.childNames.formatted(.list(type: .and).locale(locale))
        let madeLine = strings.text("Made on \(made) · \(names)")
        let replaceLine = strings.text(
            """
            Everything on this iPhone now will be replaced by what's in the copy: your family and hero, your title and \
            wardrobe, every quest, boss and moment with their notes and photos. This can't be undone.
            """
        )
        return DataImportQuestion(
            title: strings.text("Import this copy?"),
            message: replacesSaga ? madeLine + "\n\n" + replaceLine : madeLine,
            confirm: strings.text("Import"),
            cancel: strings.text("Cancel"),
            confirmIsDestructive: replacesSaga
        )
    }

    private func failure(_ error: any Error) -> State {
        if error is CancellationError { return .ready }
        return .failed(DataTransferMessages.importFailed(error, replacesSaga: replacesSaga, strings: strings))
    }
}

/// The question before an import takes the place of anything.
public struct DataImportQuestion: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirm: String
    public let cancel: String
    /// It takes the place of a saga: shown as start over is (ADR-0030 §8).
    public let confirmIsDestructive: Bool
}

/// What the import part of the page says.
public struct DataImportContent: Equatable, Sendable {
    public let title: String
    public let explanation: String
    public let button: String
    public let opening: String
    public let importing: String
    public let cancel: String

    static func make(strings: Strings, replacesSaga: Bool) -> DataImportContent {
        DataImportContent(
            title: strings.text("Import data"),
            explanation: replacesSaga
                ? strings.text(
                    "Puts the saga from a copy in place of the one on this iPhone. We'll ask before anything changes."
                )
                : strings.text(
                    """
                    If you have a copy of your saga from Export data, choose it here and pick up where you left off.
                    """
                ),
            button: strings.text("Choose a copy"),
            opening: strings.text("Opening the copy…"),
            importing: strings.text("Importing your saga…"),
            cancel: strings.text("Cancel")
        )
    }
}
