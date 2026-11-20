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

        await sut.makeFilm(reduceMotion: false)

        let script = try #require(await renderer.scripts.first)
        #expect(script.scenes.dropFirst().dropLast().map(\.card) == [
            .first(emoji: "😊", title: "Πρώτο χαμόγελο", note: nil, photoID: "p-cover"),
            .photo(photoID: "p-two"),
            .photo(photoID: "p-three")
        ])
    }
}
