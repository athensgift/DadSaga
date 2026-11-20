import Application
import AVFoundation
import CoreGraphics
import FilmTestSupport
import Foundation
import ImageIO
@testable import Presentation
import Testing

/// Every test here writes a real film, a sixth of the size except where it checks the size itself (ADR-0037 §7).
/// They run one at a time, and a film that never finishes fails its test instead of hanging the run.
@MainActor
@Suite("SagaFilmRenderer", .serialized, .timeLimit(.minutes(1)))
final class SagaFilmRendererTests {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "saga-film-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let music = FileManager.default.temporaryDirectory.appending(path: "saga-film-tone-\(UUID().uuidString).caf")

    init() throws {
        try FilmTone.write(seconds: 2, to: music)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(at: music)
    }

    // MARK: Format

    @Test(
        "Given a script of word cards one second long, when rendering at full size, then the film has the format's size",
        arguments: [SagaFilmFormat.vertical, .wide]
    )
    func fullSize(format: SagaFilmFormat) async throws {
        let renderer = SagaFilmRenderer(getPhoto: StubPhotos(), directory: directory)
        let scenes = [scene(FilmCards.chapter, seconds: 0.5), scene(FilmCards.credits, seconds: 0.5)]

        let url = try await renderer.render(script(scenes, format: format)) { _ in }

        let track = try #require(try await FilmProbe.videoTrack(url))
        let expected = format == .vertical ? CGSize(width: 1080, height: 1920) : CGSize(width: 1920, height: 1080)
        #expect(try await track.load(.naturalSize) == expected)
        #expect(try await FilmProbe.videoFormat(url)?.isH264 == true)
        #expect(try await FilmProbe.frameCount(url) == 30)
        #expect(try await FilmProbe.audioTrack(url) != nil)
        #expect(try await FilmProbe.loudness(url, from: 0, to: 0.5) > 0.05)
    }

    @Test("Given scenes of half a second, one second and a third, when rendering, then the film lasts as long as they do")
    func length() async throws {
        let scenes = [
            scene(FilmCards.chapter, seconds: 0.5),
            scene(FilmCards.first(), seconds: 1),
            scene(FilmCards.credits, seconds: 1.0 / 3)
        ]

        let url = try await small().render(script(scenes)) { _ in }

        #expect(try await FilmProbe.frameCount(url) == 55)
        #expect(try await AVURLAsset(url: url).load(.duration) == CMTime(value: 55, timescale: 30))
    }

    // MARK: Cards

    @Test(
        "Given an opening card, when rendering, then its corners are the dark ground and the family is drawn in its middle",
        arguments: [SagaFilmFormat.vertical, .wide]
    )
    func opening(format: SagaFilmFormat) async throws {
        let url = try await small().render(script([scene(FilmCards.opening, seconds: 0.5)], format: format)) { _ in }

        for corner in [(0.03, 0.03), (0.97, 0.03), (0.03, 0.97), (0.97, 0.97)] {
            let pixel = try await FilmProbe.pixel(url, at: 0.2, across: corner.0, down: corner.1)
            #expect(pixel.isGround, "corner \(corner): \(pixel)")
        }
        // Four lines across the frame at the height of the hero's head and chest, in either format.
        var drawn = 0
        for down in [0.36, 0.4, 0.44, 0.48] {
            for step in 0...12 {
                let pixel = try await FilmProbe.pixel(url, at: 0.2, across: 0.2 + Double(step) * 0.05, down: down)
                drawn += pixel.isGround ? 0 : 1
            }
        }
        #expect(drawn >= 6, "only \(drawn) of 52 points in the middle differ from the ground")
    }

    @Test(
        "Given a first with a red photo, when rendering, then the photo shows above its words, whole and untouched",
        arguments: [SagaFilmFormat.vertical, .wide]
    )
    func firstOverItsPhoto(format: SagaFilmFormat) async throws {
        let photos = StubPhotos(["p-red": try TestPhoto.jpeg { _, _ in .red }])
        let scenes = [scene(FilmCards.first(photoID: "p-red"), seconds: 0.5)]

        let url = try await small(photos).render(script(scenes, format: format, reduceMotion: true)) { _ in }

        for down in [0.1, 0.3] {
            let pixel = try await FilmProbe.pixel(url, at: 0.2, across: 0.5, down: down)
            #expect(pixel.red > 180 && pixel.green < 70 && pixel.blue < 70, "\(down) down: \(pixel)")
        }
    }

    @Test(
        "Given a first with a white photo, when rendering, then under its words the photo is dark enough for white text",
        arguments: [SagaFilmFormat.vertical, .wide]
    )
    func wordsStayReadable(format: SagaFilmFormat) async throws {
        let photos = StubPhotos(["p-white": try TestPhoto.jpeg { _, _ in .white }])
        let scenes = [scene(FilmCards.first(photoID: "p-white"), seconds: 0.5)]

        let url = try await small(photos).render(script(scenes, format: format, reduceMotion: true)) { _ in }

        // In the bottom margin, below the words, only the scrim covers the photo. 4.5:1 is WCAG's AA for small text.
        let under = try await FilmProbe.pixel(url, at: 0.2, across: 0.5, down: 0.97)
        #expect(1.05 / (under.luminance + 0.05) >= 4.5, "under the words: \(under)")
        #expect(try await FilmProbe.pixel(url, at: 0.2, across: 0.5, down: 0.2).luminance > 0.9)
    }

    @Test(
        "Given a photo that can't be read, when rendering, then the film is still made and its scene is dark",
        arguments: [nil, Data("not a photo".utf8)]
    )
    func unreadablePhoto(data: Data?) async throws {
        let photos = StubPhotos(["p-broken": data].compactMapValues(\.self))
        let scenes = [
            scene(FilmCards.first(photoID: "p-broken"), seconds: 0.5),
            scene(.photo(photoID: "p-broken"), seconds: 0.5)
        ]

        let url = try await small(photos).render(script(scenes)) { _ in }

        #expect(try await FilmProbe.frameCount(url) == 30)
        for seconds in [0.2, 0.9] {
            let pixel = try await FilmProbe.pixel(url, at: seconds, across: 0.5, down: 0.2)
            #expect(max(pixel.red, pixel.green, pixel.blue) < 40, "at \(seconds) s: \(pixel)")
        }
    }

    // MARK: Motion

    @Test("Given a photo, when rendering, then it glides closer; with Reduce Motion it stays still", arguments: [false, true])
    func kenBurns(reduceMotion: Bool) async throws {
        // Red rises across the photo's left edge, so a small move of the camera changes it a lot.
        let photos = StubPhotos(["p-ramp": try TestPhoto.jpeg { column, _ in
            TestPhoto.Paint(red: UInt8(min(255, column * 255 / 27)))
        }])
        let scenes = [scene(.photo(photoID: "p-ramp"), seconds: 1)]

        let url = try await small(photos).render(script(scenes, reduceMotion: reduceMotion)) { _ in }

        let first = try await FilmProbe.pixel(url, at: 0, across: 0.045, down: 0.5)
        let last = try await FilmProbe.pixel(url, at: 0.96, across: 0.045, down: 0.5)
        if reduceMotion {
            #expect(abs(last.red - first.red) < 12, "\(first) then \(last)")
        } else {
            #expect(last.red - first.red > 40, "\(first) then \(last)")
        }
    }

    @Test("Given a photo after a card, when its scene starts, then it fades in over twelve frames")
    func scenesFadeIn() async throws {
        let photos = StubPhotos(["p-red": try TestPhoto.jpeg { _, _ in .red }])
        let scenes = [scene(FilmCards.chapter, seconds: 1), scene(.photo(photoID: "p-red"), seconds: 1)]

        let url = try await small(photos).render(script(scenes, reduceMotion: true)) { _ in }

        #expect(try await FilmProbe.pixel(url, at: 0.5, across: 0.5, down: 0.1).isGround)
        let early = try await FilmProbe.pixel(url, at: 1 + 2.5 / 30, across: 0.5, down: 0.1)
        #expect(early.red > 55 && early.red < 190, "frame 2 of the fade: \(early)")
        let late = try await FilmProbe.pixel(url, at: 1 + 8.5 / 30, across: 0.5, down: 0.1)
        #expect(late.red > early.red + 30 && late.red < 240, "frame 8 of the fade: \(late)")
        #expect(try await FilmProbe.pixel(url, at: 1 + 12.5 / 30, across: 0.5, down: 0.1).red > 240)
    }

    @Test("Given two quest photos in a row, when the second starts, then it has faded in after nine frames")
    func montageFadesFaster() async throws {
        let photos = StubPhotos([
            "p-red": try TestPhoto.jpeg { _, _ in .red },
            "p-blue": try TestPhoto.jpeg { _, _ in .blue }
        ])
        let scenes = [scene(.photo(photoID: "p-red"), seconds: 1), scene(.photo(photoID: "p-blue"), seconds: 1)]

        let url = try await small(photos).render(script(scenes, reduceMotion: true)) { _ in }

        let fading = try await FilmProbe.pixel(url, at: 1 + 4.5 / 30, across: 0.5, down: 0.5)
        #expect(fading.red > 40 && fading.blue > 40, "frame 4 of the fade: \(fading)")
        let faded = try await FilmProbe.pixel(url, at: 1 + 9.5 / 30, across: 0.5, down: 0.5)
        #expect(faded.red < 25 && faded.blue > 200, "frame 9: \(faded)")
    }

    // MARK: Files

    @Test("Given a script titled with the child's name, when rendering, then the file has that name and says no place")
    func fileNameAndMetadata() async throws {
        let url = try await small().render(script([scene(FilmCards.chapter, seconds: 0.5)], title: "Άννα – DadSaga")) { _ in }

        #expect(url.lastPathComponent == "Άννα – DadSaga.mp4")
        #expect(url.deletingLastPathComponent().deletingLastPathComponent().path == directory.path)
        let asset = AVURLAsset(url: url)
        var items = try await asset.load(.metadata)
        for format in try await asset.load(.availableMetadataFormats) {
            items += try await asset.loadMetadata(for: format)
        }
        let keys = items.compactMap { $0.identifier?.rawValue.lowercased() }
        #expect(!keys.contains { $0.contains("location") || $0.contains("gps") || $0.contains("creationdate") }, "\(keys)")
    }

    @Test("Given an earlier film, when rendering the next, then only the new one exists; when discarding, none does")
    func oneFilmAtATime() async throws {
        let renderer = small()
        let scenes = [scene(FilmCards.chapter, seconds: 0.5)]
        let earlier = try await renderer.render(script(scenes, title: "first")) { _ in }

        let later = try await renderer.render(script(scenes, title: "second")) { _ in }

        #expect(!FileManager.default.fileExists(atPath: earlier.path))
        #expect(films().map(\.lastPathComponent) == ["second.mp4"])
        #expect(try await FilmProbe.frameCount(later) == 15)

        await renderer.discardFilms()
        await renderer.discardFilms()
        #expect(films().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: later.path))
    }

    @Test("Given a film being rendered, when its task is cancelled, then it stops with CancellationError and no film")
    func cancelling() async throws {
        let renderer = small()
        let long = script((0..<40).map { _ in scene(FilmCards.chapter, seconds: 3) })
        let (started, signal) = AsyncStream<Void>.makeStream()
        let task = Task {
            try await renderer.render(long) { _ in signal.yield() }
        }
        var waiting = started.makeAsyncIterator()
        _ = await waiting.next()

        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(films().isEmpty)
    }

    @Test("Given music that isn't there, when rendering, then it fails and leaves no film")
    func failing() async throws {
        let missing = SagaFilmScript(
            format: .vertical, reduceMotion: false, scenes: [scene(FilmCards.chapter, seconds: 0.5)],
            music: directory.appending(path: "no-music.m4a"), title: "film"
        )
        let seen = Seen()

        await #expect(throws: (any Error).self) {
            try await self.small().render(missing) { seen.values.append($0) }
        }
        #expect(films().isEmpty)
        #expect(!seen.values.contains(1))
    }

    @Test("Given a film, when rendering, then progress has risen to 1 on the main actor by the time the film is returned")
    func progress() async throws {
        let seen = Seen()
        let scenes = [scene(FilmCards.opening, seconds: 1), scene(FilmCards.credits, seconds: 1)]

        _ = try await small().render(script(scenes)) { value in
            MainActor.assertIsolated()
            seen.values.append(value)
        }

        let values = seen.values
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
        #expect(values.allSatisfy { $0 > 0 && $0 <= 1 })
        #expect(values.last == 1)
    }

    // MARK: Helpers

    /// A renderer of films a sixth of the size: 180 × 320 or 320 × 180.
    func small(_ photos: StubPhotos = StubPhotos()) -> SagaFilmRenderer {
        SagaFilmRenderer(getPhoto: photos, directory: directory, pixelScale: 1.0 / 6)
    }

    func scene(_ card: SagaFilmCard, seconds: Double) -> SagaFilmScene {
        SagaFilmScene(seconds: seconds, card: card)
    }

    func script(
        _ scenes: [SagaFilmScene],
        format: SagaFilmFormat = .vertical,
        reduceMotion: Bool = false,
        title: String = "film"
    ) -> SagaFilmScript {
        SagaFilmScript(format: format, reduceMotion: reduceMotion, scenes: scenes, music: music, title: title)
    }

    /// The films in the renderer's folder now.
    func films() -> [URL] {
        let files = FileManager.default
        let folders = (try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders
            .flatMap { (try? files.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
            .filter { $0.pathExtension == "mp4" }
    }
}
