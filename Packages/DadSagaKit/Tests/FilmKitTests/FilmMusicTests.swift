import AVFoundation
import FilmKit
import Foundation
import Testing

extension FilmKitTests {
    @Suite("Music")
    struct MusicTests {
        let encoder = FilmEncoder()

        @Test("Given a 1 s tone under a 3 s film, when encoding, then the music loops to the film's end and no further")
        func musicLoopsToTheEnd() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try Fixture.tone(seconds: 1, at: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let timeline = FilmTimeline(
                spec: Fixture.portrait,
                clips: Fixture.solids([Fixture.red, Fixture.green, Fixture.blue]),
                music: FilmMusic(url: tone, fadeOutSeconds: 0.5)
            )
            let url = try await Fixture.encode(timeline)
            defer { try? FileManager.default.removeItem(at: url) }

            let audio = try #require(try await FilmProbe.audioTrack(url))
            let range = try await audio.load(.timeRange)

            #expect(abs(range.duration.seconds - 3) < 0.05)
            #expect(range.end.seconds <= 3 + 1024.0 / 48_000)
            #expect(try await FilmProbe.loudness(url, from: 1.4, to: 1.6) > 0.1)
        }

        @Test("Given a 3 s tone and no fade under a 1 s film, when encoding, then the music is cut at the film's end, still loud")
        func musicLongerThanTheFilm() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try Fixture.tone(seconds: 3, at: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let timeline = Fixture.solidFilm([Fixture.red], music: FilmMusic(url: tone, fadeOutSeconds: 0))
            let url = try await Fixture.encode(timeline)
            defer { try? FileManager.default.removeItem(at: url) }

            let audio = try #require(try await FilmProbe.audioTrack(url))
            let range = try await audio.load(.timeRange)

            #expect(try await AVURLAsset(url: url).load(.duration) == CMTime(value: 30, timescale: 30))
            #expect(abs(range.duration.seconds - 1) < 0.05)
            #expect(range.end.seconds <= 1 + 1024.0 / 48_000)
            #expect(try await FilmProbe.loudness(url, from: 0.8, to: 0.95) > 0.15)
        }

        @Test("Given a 1 s fade-out, when encoding, then the film's last tenth of a second is far quieter than its middle")
        func musicFadesOut() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try Fixture.tone(seconds: 3, at: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let timeline = FilmTimeline(
                spec: Fixture.portrait,
                clips: Fixture.solids([Fixture.red, Fixture.green, Fixture.blue]),
                music: FilmMusic(url: tone, fadeOutSeconds: 1)
            )
            let url = try await Fixture.encode(timeline)
            defer { try? FileManager.default.removeItem(at: url) }

            let middle = try await FilmProbe.loudness(url, from: 1.4, to: 1.6)
            let ending = try await FilmProbe.loudness(url, from: 2.9, to: 3)

            #expect(middle > 0.15, "\(middle)")
            #expect(ending < middle / 5, "\(ending) after \(middle)")
        }

        @Test("Given music with no sound in it, when encoding, then it fails as music without audio and leaves no file")
        func musicWithoutSoundStopsThePictures() async throws {
            let silent = try await Fixture.encode(Fixture.solidFilm([Fixture.red], frames: 5))
            defer { try? FileManager.default.removeItem(at: silent) }
            let url = Fixture.temporaryURL()
            let timeline = FilmTimeline(
                spec: Fixture.portrait,
                clips: Fixture.solids([Fixture.red, Fixture.green], frames: 300),
                music: FilmMusic(url: silent)
            )

            await #expect(throws: FilmError.musicHasNoAudio(silent)) { try await encoder.encode(timeline, to: url) }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }

        @Test("Given a music file cut off half-way, when encoding, then it fails and leaves no file")
        func damagedMusicFails() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try Fixture.tone(seconds: 2, at: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let whole = try Data(contentsOf: tone)
            try whole.prefix(whole.count / 2).write(to: tone)
            let url = Fixture.temporaryURL()
            let timeline = FilmTimeline(
                spec: Fixture.portrait,
                clips: Fixture.solids([Fixture.red, Fixture.green, Fixture.blue]),
                music: FilmMusic(url: tone)
            )

            await #expect(throws: (any Error).self) { try await encoder.encode(timeline, to: url) }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }

        @Test("Given a tone of a fifth of a second, when encoding, then it fails as music too short to loop")
        func musicTooShortToLoop() async throws {
            let tone = Fixture.temporaryURL(extension: "caf")
            try Fixture.tone(seconds: 0.2, at: tone)
            defer { try? FileManager.default.removeItem(at: tone) }
            let url = Fixture.temporaryURL()
            let timeline = FilmTimeline(spec: Fixture.portrait, clips: Fixture.solids([Fixture.red]), music: FilmMusic(url: tone))

            await #expect(throws: FilmError.musicTooShort(tone)) { try await encoder.encode(timeline, to: url) }
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }
}
