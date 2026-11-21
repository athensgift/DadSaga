import Application
import Domain
import Foundation
import Testing

/// Choosing a film's further photos and finding what its camera looks at (ADR-0047).
@Suite("Saga film photos")
struct SagaFilmPhotosUseCaseTests {
    let film = SagaFilmUseCaseTests()

    /// A first with a cover and four further photos, in the film of everything.
    func firstWithFivePhotos() async throws -> SagaFilm {
        try await film.family()
        try await film.progress.add(ProgressEvent(
            kind: .first(id: "f-walk"), childID: film.anna.id, date: film.date(months: 3),
            photoIDs: ["cover", "a", "b", "c", "d"]
        ))
        return try #require(try await film.sut().execute(childID: nil, period: .everything, on: film.date(months: 4)))
    }

    @Test("Given a first with four further photos, when choosing, then the three best play and only they are read")
    func choosesTheBest() async throws {
        let original = try await firstWithFivePhotos()
        let analyzer = FakePhotoAnalyzer(ratings: ["a": -0.5, "b": 0.9, "c": 0.1, "d": 0.4])
        let store = NamedPhotoStore()

        let chosen = await DefaultChooseSagaFilmPhotosUseCase(photoStore: store, analyzer: analyzer).execute(original)

        #expect(Self.photoIDs(in: original) == ["a", "b", "c"])
        #expect(Self.photoIDs(in: chosen) == ["b", "c", "d"])
        #expect(chosen.storyboard.seconds == original.storyboard.seconds)
        #expect(await store.read.sorted() == ["a", "b", "c", "d"])
    }

    @Test("Given photos the device can't rate, when choosing, then the film is the one the sheet showed")
    func unratedKeepsTheFilm() async throws {
        let original = try await firstWithFivePhotos()

        let chosen = await DefaultChooseSagaFilmPhotosUseCase(
            photoStore: NamedPhotoStore(), analyzer: FakePhotoAnalyzer()
        ).execute(original)

        #expect(chosen.storyboard == original.storyboard)
    }

    @Test("Given every further photo fits, when choosing, then no photo is read")
    func nothingToChoose() async throws {
        try await film.family()
        try await film.progress.add(ProgressEvent(
            kind: .first(id: "f-walk"), childID: film.anna.id, date: film.date(months: 3), photoIDs: ["cover", "a"]
        ))
        let original = try #require(try await film.sut().execute(childID: nil, period: .everything, on: film.date(months: 4)))
        let store = NamedPhotoStore()

        let chosen = await DefaultChooseSagaFilmPhotosUseCase(
            photoStore: store, analyzer: FakePhotoAnalyzer(ratings: ["a": 1])
        ).execute(original)

        #expect(chosen.storyboard == original.storyboard)
        #expect(await store.read.isEmpty)
    }

    @Test("Given a child and an adult, when finding the subject, then it is around the child")
    func subjectIsTheChild() async throws {
        let child = PhotoRegion(left: 0.1, top: 0.4, width: 0.2, height: 0.2)
        let adult = PhotoRegion(left: 0.6, top: 0.1, width: 0.25, height: 0.25)
        let analyzer = FakePhotoAnalyzer(faces: [
            PhotoFace(region: adult, isChild: false), PhotoFace(region: child, isChild: true)
        ])

        let framing = try #require(await DefaultFindPhotoSubjectUseCase(analyzer: analyzer).execute(photo: Data()))
        let subject = framing.region

        #expect(framing.showsChild)
        #expect(subject.left < child.left && subject.right > child.right && subject.right < adult.left)
    }

    @Test("Given no face, when finding the subject, then it is what draws the eye; with nothing, none")
    func salientWithoutFaces() async {
        let ball = PhotoRegion(left: 0.2, top: 0.5, width: 0.1, height: 0.1)

        #expect(await DefaultFindPhotoSubjectUseCase(analyzer: FakePhotoAnalyzer(salient: [ball]))
            .execute(photo: Data()) == PhotoFraming(region: ball, showsChild: false))
        #expect(await DefaultFindPhotoSubjectUseCase(analyzer: FakePhotoAnalyzer()).execute(photo: Data()) == nil)
    }

    private static func photoIDs(in film: SagaFilm) -> [String] {
        film.storyboard.scenes.compactMap { if case .photo(_, let id) = $0.kind { id } else { nil } }
    }
}

/// Answers by the photo's id, which `NamedPhotoStore` hands out as its data.
struct FakePhotoAnalyzer: PhotoAnalyzer {
    var ratings: [String: Double] = [:]
    var faces: [PhotoFace] = []
    var salient: [PhotoRegion] = []

    func rating(of imageData: Data) async -> PhotoRating? {
        String(bytes: imageData, encoding: .utf8).flatMap { ratings[$0] }.map { PhotoRating(score: $0, isUtility: false) }
    }

    func faces(in imageData: Data) async -> [PhotoFace] { faces }
    func salientObjects(in imageData: Data) async -> [PhotoRegion] { salient }
}

/// Every id is a photo whose data is its id; it remembers which were read.
actor NamedPhotoStore: PhotoStore {
    private(set) var read: [String] = []

    func save(_ imageData: Data) async throws -> String { UUID().uuidString }

    func thumbnail(id: String, maxPixelSize: Int) async -> Data? {
        read.append(id)
        return Data(id.utf8)
    }

    func delete(id: String) async {}
    func deleteAll() async {}
    func storedPhotos() async throws -> [StoredPhoto] { [] }
}
