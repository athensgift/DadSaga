import Application
import Domain
import FilmKit
import Foundation
@testable import Presentation
import Testing

/// The film's camera on each photo's subject: the children first, at most 1.25 (ADR-0044 §3).
@Suite("Saga film: framing a photo")
struct SagaFilmFramingTests {
    let spec = FilmSpec(width: 180, height: 320)

    let small = PhotoRegion(left: 0.3, top: 0.2, width: 0.1, height: 0.1)

    func loader(subject: PhotoFraming?) throws -> SagaFilmPhotoLoader {
        let photo = try TestPhoto.jpeg { _, _ in .white }
        return SagaFilmPhotoLoader(getPhoto: StubPhotos(["p": photo]), findSubject: FixedPhotoSubject(subject: subject))
    }

    @Test("Given a photo of a child, when its turn is to glide out, then it glides in on the child at 1.25")
    func childAlwaysGlidesIn() async throws {
        let photo = try await loader(subject: PhotoFraming(region: small, showsChild: true))
            .photo(id: "p", spec: spec, glide: .outward)

        guard case .kenBurns(let start, let end) = try #require(photo.motion) else {
            Issue.record("The photo should glide")
            return
        }
        #expect(start == FilmCamera())
        #expect(end.zoom == 1.25)
        #expect(abs(end.centerX - 0.4) < 1e-9 && abs(end.centerY - 0.4) < 1e-9)
    }

    @Test("Given a photo of adults only, when its turn is to glide out, then it glides out from their faces")
    func adultsGlideOut() async throws {
        let photo = try await loader(subject: PhotoFraming(region: small, showsChild: false))
            .photo(id: "p", spec: spec, glide: .outward)

        guard case .kenBurns(let start, let end) = try #require(photo.motion) else {
            Issue.record("The photo should glide")
            return
        }
        #expect(start.zoom == 1.25 && abs(start.centerX - 0.4) < 1e-9)
        #expect(end == FilmCamera())
    }

    @Test("Given a photo with no subject, when it glides out, then it starts from today's close-up")
    func noSubjectKeepsTodaysGlide() async throws {
        let photo = try await loader(subject: nil).photo(id: "p", spec: spec, glide: .outward)

        guard case .kenBurns(let start, let end) = try #require(photo.motion) else {
            Issue.record("The photo should glide")
            return
        }
        #expect(start == FilmCamera(zoom: 1.12, centerX: 0.5, centerY: 0.45))
        #expect(end == FilmCamera())
    }

    @Test("Given Reduce Motion, when the photo loads, then it keeps the clip's stillness")
    func stillPhotoStaysStill() async throws {
        let photo = try await loader(subject: PhotoFraming(region: small, showsChild: true))
            .photo(id: "p", spec: spec, glide: nil)

        #expect(photo.motion == nil)
    }
}
