import Application
import Domain
import Foundation
@testable import Presentation
import Testing

/// An entry's further photos in the film (ADR-0042 §6).
@MainActor
@Suite("SagaFilmViewModel: an entry's photos", .timeLimit(.minutes(1)))
struct SagaFilmPhotosTests: SagaFilmSheetTests {
    let renderer = FakeFilmRenderer()

    @Test("Given a first with three photos, when making the film, then its card is over the cover and two photos follow")
    func firstWithThreePhotos() async throws {
        let smile = ProgressEvent(
            kind: .first(id: "f-smile"), childID: FilmStub.anna.id, date: FilmStub.months(2),
            photoIDs: ["p-cover", "p-two", "p-three"]
        )
        let sut = makeSUT(FakeGetSagaFilm(events: [smile]))
        await sut.onAppear()
        await sut.selectPeriod(id: "year-1")
        await sut.setShowsDates(false)?.value

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        #expect(script.scenes.dropFirst().dropLast().map(\.card) == [
            .first(emoji: "😊", title: "Πρώτο χαμόγελο", date: nil, note: nil, photoID: "p-cover"),
            .photo(photoID: "p-two"),
            .photo(photoID: "p-three")
        ])
    }

    @Test("Given a first with four further photos, when making the film, then its three best play (ADR-0044)")
    func bestFurtherPhotosPlay() async throws {
        let walk = ProgressEvent(
            kind: .first(id: "f-smile"), childID: FilmStub.anna.id, date: FilmStub.months(2),
            photoIDs: ["p-cover", "p-a", "p-b", "p-c", "p-d"]
        )
        let choose = DefaultChooseSagaFilmPhotosUseCase(
            photoStore: IDPhotoStore(),
            analyzer: ScoreByID(scores: ["p-a": -0.8, "p-b": 0.5, "p-c": 0.1, "p-d": 0.9])
        )
        let sut = makeSUT(FakeGetSagaFilm(events: [walk]), choosePhotos: choose)
        await sut.onAppear()
        await sut.selectPeriod(id: "year-1")

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        #expect(script.scenes.compactMap { if case .photo(let id) = $0.card { id } else { nil } } == ["p-b", "p-c", "p-d"])
    }
}

/// Every id is a photo whose bytes are its id.
private struct IDPhotoStore: PhotoStore {
    func save(_ imageData: Data) async throws -> String { "" }
    func thumbnail(id: String, maxPixelSize: Int) async -> Data? { Data(id.utf8) }
    func delete(id: String) async {}
    func deleteAll() async {}
}

/// Rates a photo by its id.
private struct ScoreByID: PhotoAnalyzer {
    let scores: [String: Double]

    func rating(of imageData: Data) async -> PhotoRating? {
        String(bytes: imageData, encoding: .utf8).flatMap { scores[$0] }.map { PhotoRating(score: $0, isUtility: false) }
    }

    func faces(in imageData: Data) async -> [PhotoFace] { [] }
    func salientObjects(in imageData: Data) async -> [PhotoRegion] { [] }
}
