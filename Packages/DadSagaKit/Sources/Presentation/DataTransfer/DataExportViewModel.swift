import Application
import Foundation
import Localization
import Observation

/// Presenter for Settings › Export data (ADR-0057 §6, §8): exporting the saga to one file the dad saves or sends, and,
/// below it, importing one. Nothing here is ever asked for or counted (ADR-0006).
@MainActor
@Observable
public final class DataExportViewModel: Identifiable {
    public enum State: Equatable {
        case ready
        /// Writing the file; the fraction done.
        case exporting(Double)
        case exported(ExportedData)
        case failed(String)
    }

    public let content: DataExportContent
    public private(set) var state: State = .ready
    /// The import part of the page.
    public let importer: DataImportViewModel

    /// Exporting or importing: the page can't be left, and a link from outside waits (ADR-0050 §4).
    public var isWorking: Bool {
        if case .exporting = state { return true }
        return importer.isWorking
    }

    private let makeCopy: any MakeSagaCopyUseCase
    private let backgroundTime: any BackgroundTime
    private let locale: Locale
    private let now: @Sendable () -> Date
    private var exporting: Task<MadeSagaCopy, any Error>?
    private var strings: Strings { Strings(locale: locale) }

    public init(
        makeCopy: any MakeSagaCopyUseCase,
        backgroundTime: any BackgroundTime,
        importer: DataImportViewModel,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.makeCopy = makeCopy
        self.backgroundTime = backgroundTime
        self.importer = importer
        self.locale = locale
        self.now = now
        content = DataExportContent.make(strings: Strings(locale: locale))
    }

    public func export() async {
        guard !isWorking else { return }
        state = .exporting(0)
        let (fractions, progress) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        let showing = Task { [weak self] in
            for await fraction in fractions where self?.isExporting == true { self?.state = .exporting(fraction) }
        }
        let makeCopy = makeCopy
        let date = now()
        let work = Task { [backgroundTime] in
            try await backgroundTime.run("Export data") {
                try await makeCopy.execute(on: date) { progress.yield($0) }
            }
        }
        exporting = work
        defer {
            progress.finish()
            showing.cancel()
            exporting = nil
        }
        do {
            let made = try await work.value
            state = .exported(ExportedData(file: made.url, readyLine: readyLine(byteCount: made.byteCount)))
        } catch is CancellationError {
            state = .ready
        } catch {
            state = .failed(DataTransferMessages.exportFailed(error, strings: strings))
        }
    }

    /// Stops the export; no file is left.
    public func cancel() {
        exporting?.cancel()
    }

    private var isExporting: Bool {
        if case .exporting = state { true } else { false }
    }

    private func readyLine(byteCount: Int64) -> String {
        let size = byteCount.formatted(.byteCount(style: .file).locale(locale))
        return strings.text("Your copy is ready · \(size)")
    }
}

/// An exported file, ready to be saved or sent.
public struct ExportedData: Equatable, Sendable {
    let file: URL
    public let readyLine: String
}

/// What the export part of the page says.
public struct DataExportContent: Equatable, Sendable {
    public let title: String
    public let explanation: String
    public let button: String
    public let exporting: String
    public let share: String
    public let noPassword: String
    public let cancel: String

    static func make(strings: Strings) -> DataExportContent {
        DataExportContent(
            title: strings.text("Export data"),
            explanation: strings.text(
                """
                One file with your saga: your family and hero, your title and wardrobe, every quest, boss and moment \
                with their notes and photos. Keep it in Files or on a computer, or send it to another iPhone.
                """
            ),
            button: strings.text("Make a copy"),
            exporting: strings.text("Making your copy…"),
            share: strings.text("Save or send"),
            noPassword: strings.text(
                """
                It has no password: it always opens, for you and for anyone who has the file. Keep it where you'd keep \
                your photos.
                """
            ),
            cancel: strings.text("Cancel")
        )
    }
}
