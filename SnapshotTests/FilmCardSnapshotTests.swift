import Presentation
import SnapshotTesting
import Synchronization
import Testing
import UIKit

/// The saga film's cards as images, exactly as `SagaFilmRenderer` draws them into a film (ADR-0037 §7): the script
/// comes from the film sheet's own view model, so a change to what a card says or how it looks shows up in review.
/// A card over a photo is drawn as its own layer, clear where the photo shows through.
@MainActor
@Suite("Film card snapshots", .serialized)
struct FilmCardSnapshotTests {
    enum Look: String, CaseIterable {
        case greekVertical = "el-vertical"
        case englishWide = "en-wide"

        var locale: Locale { Locale(identifier: self == .greekVertical ? "el_GR" : "en_US") }
        var format: SagaFilmFormat { self == .greekVertical ? .vertical : .wide }
    }

    @Test("Given firsts, a photo and a boss, when the film is drawn, then its cards look as recorded", arguments: Look.allCases)
    func cards(look: Look) async throws {
        let script = try await script(look: look)
        let cards = script.scenes.map(\.card)

        try verify(cards.first(where: \.isOpening), look: look, named: "film-card-opening")
        try verify(cards.first(where: \.isFirstWithNote), look: look, named: "film-card-first-note")
        try verify(cards.first(where: \.isFirstWithPhoto), look: look, named: "film-card-first-photo")
        try verify(cards.first(where: \.isBoss), look: look, named: "film-card-boss")
        try verify(cards.first(where: \.isCredits), look: look, named: "film-card-credits")
    }

    /// The script the sheet hands its renderer for the whole saga, in the look's language and format.
    private func script(look: Look) async throws -> SagaFilmScript {
        let renderer = ScriptCatcher()
        let viewModel = try await SagaFixture(locale: look.locale).filmed().sagaFilm(renderer: renderer)
        await viewModel.onAppear()
        viewModel.selectFormat(look.format)
        await viewModel.makeFilm(reduceMotion: false)
        return try #require(renderer.script)
    }

    private func verify(
        _ card: SagaFilmCard?, look: Look, named name: String,
        fileID: StaticString = #fileID, file: StaticString = #filePath, line: UInt = #line, column: UInt = #column
    ) throws {
        let card = try #require(card, "The film has no such card: \(name)")
        let drawn = UIImage(cgImage: try SagaFilmRenderer.cardImage(card, format: look.format))
        // Through PNG before it is compared, like the reference it is compared with (see `savedScreen`).
        let saved = try #require(drawn.pngData().flatMap { UIImage(data: $0) })
        assertSnapshot(
            of: saved,
            as: .image(precision: 0.999, perceptualPrecision: 0.98),
            named: look.rawValue,
            fileID: fileID, file: file, testName: name, line: line, column: column
        )
    }
}

/// Keeps the script it is asked to draw, and draws nothing.
private final class ScriptCatcher: SagaFilmRendering {
    private let caught = Mutex<SagaFilmScript?>(nil)

    var script: SagaFilmScript? { caught.withLock(\.self) }

    func render(_ script: SagaFilmScript, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> URL {
        caught.withLock { $0 = script }
        throw CancellationError()
    }

    func discardFilms() async {}
}

private extension SagaFilmCard {
    var isOpening: Bool {
        if case .opening = self { true } else { false }
    }

    var isFirstWithNote: Bool {
        if case .first(_, _, _, let note, nil) = self { note != nil } else { false }
    }

    var isFirstWithPhoto: Bool {
        if case .first(_, _, _, _, let photoID) = self { photoID != nil } else { false }
    }

    var isBoss: Bool {
        if case .boss = self { true } else { false }
    }

    var isCredits: Bool {
        if case .credits = self { true } else { false }
    }
}
