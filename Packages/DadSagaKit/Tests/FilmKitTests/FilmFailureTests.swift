import AVFoundation
import FilmKit
import FilmTestSupport
import Foundation
import Synchronization
import Testing

extension FilmKitTests {
    @Suite("Refusals, failures and cancelling")
    struct FailureTests {
        let encoder = FilmEncoder()

        @Test("Given no clips, when encoding, then it fails as an empty timeline")
        func emptyTimeline() async {
            await #expect(throws: FilmError.emptyTimeline) {
                try await encoder.encode(FilmTimeline(spec: Fixture.portrait, clips: []), to: Fixture.temporaryURL())
            }
        }

        @Test(
            "Given a spec H.264 can't take, when encoding, then it fails as an invalid spec and leaves what was there",
            arguments: [
                FilmSpec(width: 181, height: 320),
                FilmSpec(width: 180, height: 0),
                FilmSpec(width: -180, height: 320),
                FilmSpec(width: 180, height: 320, framesPerSecond: 0),
                FilmSpec(width: 180, height: 320, videoBitRate: 0),
                FilmSpec(width: 180, height: 320, audioSampleRate: -1),
                FilmSpec(width: 180, height: 320, audioBitRate: 0)
            ]
        )
        func invalidSpec(spec: FilmSpec) async throws {
            let url = Fixture.temporaryURL()
            try Data("kept".utf8).write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            await #expect(throws: FilmError.invalidSpec(spec)) {
                try await encoder.encode(FilmTimeline(spec: spec, clips: Fixture.solids([Fixture.red])), to: url)
            }
            #expect(try Data(contentsOf: url) == Data("kept".utf8))
        }

        @Test(
            "Given a fade-out that is negative or not a number, when encoding, then it fails as an invalid fade-out",
            arguments: [-1, Double.infinity, Double.nan]
        )
        func invalidFadeOut(seconds: Double) async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try FilmTone.write(seconds: 1, to: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let music = FilmMusic(url: tone, fadeOutSeconds: seconds)

            await #expect(throws: FilmError.invalidFadeOut) {
                try await encoder.encode(Fixture.solidFilm([Fixture.red], music: music), to: Fixture.temporaryURL())
            }
        }

        @Test("Given a film, when encoding, then progress rises after every frame and reaches 1 only once the file is whole")
        func progressRises() async throws {
            let seen = Mutex<[Double]>([])
            let wasWholeAtOne = Mutex<Bool?>(nil)
            let url = Fixture.temporaryURL()
            let timeline = FilmTimeline(spec: Fixture.portrait, clips: Fixture.solids([Fixture.red, Fixture.blue]))
            try await encoder.encode(timeline, to: url) { value in
                seen.withLock { $0.append(value) }
                if value >= 1 {
                    // The writer adds the film's index, its `moov` box, only when it finishes the file.
                    let index = (try? Data(contentsOf: url))?.range(of: Data("moov".utf8))
                    wasWholeAtOne.withLock { $0 = index != nil }
                }
            }
            defer { try? FileManager.default.removeItem(at: url) }

            let values = seen.withLock { $0 }
            #expect(values.count == 61)
            #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
            #expect(values.dropLast().allSatisfy { $0 > 0 && $0 < 1 })
            #expect(values.last == 1)
            #expect(wasWholeAtOne.withLock { $0 } == true)
        }

        @Test(
            "Given a film being written, when its task is cancelled, then it stops with CancellationError and no file",
            arguments: [false, true]
        )
        func cancellationLeavesNoFile(withMusic: Bool) async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try FilmTone.write(seconds: 1, to: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let url = Fixture.temporaryURL()
            let (started, signal) = AsyncStream<Void>.makeStream()
            let timeline = FilmTimeline(
                spec: Fixture.portrait,
                clips: Fixture.solids([Fixture.red, Fixture.green], frames: 300),
                music: withMusic ? FilmMusic(url: tone) : nil
            )
            let task = Task { [encoder] in
                try await encoder.encode(timeline, to: url) { _ in signal.yield() }
            }
            var iterator = started.makeAsyncIterator()
            _ = await iterator.next()
            task.cancel()

            await #expect(throws: CancellationError.self) { try await task.value }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }

        @Test("Given a picture that fails to load under music, when encoding, then it fails with that error and leaves no file")
        func pictureFailureStopsTheMusic() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try FilmTone.write(seconds: 1, to: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let url = Fixture.temporaryURL()
            let progress = Mutex<[Double]>([])
            // The pause lets the music run ahead until the writer holds it back, waiting for pictures.
            let clips = Fixture.solids([Fixture.red]) + [FilmClip(frames: 300, picture: .image {
                try await Task.sleep(for: .milliseconds(300))
                throw Fixture.Failure()
            })]
            let timeline = FilmTimeline(spec: Fixture.portrait, clips: clips, music: FilmMusic(url: tone))

            await #expect(throws: Fixture.Failure.self) {
                try await encoder.encode(timeline, to: url) { value in progress.withLock { $0.append(value) } }
            }
            #expect(!FileManager.default.fileExists(atPath: url.path))
            #expect(progress.withLock { $0 }.allSatisfy { $0 < 1 })
        }

        @Test("Given a card that fails to load, when encoding, then it fails with that error and leaves no file")
        func overlayFailure() async throws {
            let url = Fixture.temporaryURL()
            let card = FilmClip(frames: 30, picture: .solid(Fixture.blue), overlay: { throw Fixture.Failure() })
            let clips = Fixture.solids([Fixture.red]) + [card]

            await #expect(throws: Fixture.Failure.self) {
                try await encoder.encode(FilmTimeline(spec: Fixture.portrait, clips: clips), to: url)
            }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }
}
