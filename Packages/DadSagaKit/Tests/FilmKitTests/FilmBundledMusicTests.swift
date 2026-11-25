import AVFoundation
import FilmKit
import FilmTestSupport
import Foundation
import SagaMusic
import Testing

extension FilmKitTests {
    /// The other music tests use a PCM tone made in the test. A real film takes a shipped track: AAC at 44.1 kHz with
    /// priming frames, resampled to the film's rate and cut at its end. Whether its sound reaches the film's end
    /// depends on the system's decoder, so each shipped file is encoded here (ADR-0036 §3 and §8).
    @Suite("Bundled music")
    struct BundledMusicTests {
        @Test("Given each bundled track under a 2 s film, when encoding, then the film is made, heard from its start to its end")
        func everyBundledTrackEncodes() async throws {
            let tracks = (SagaMusic.bundle.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            try #require(!tracks.isEmpty)

            for track in tracks {
                let name = Comment(rawValue: track.lastPathComponent)
                let timeline = Fixture.solidFilm([Fixture.red, Fixture.green], music: FilmMusic(url: track, fadeOutSeconds: 0))
                let url = try await Fixture.encode(timeline)
                defer { try? FileManager.default.removeItem(at: url) }

                let audio = try #require(try await FilmProbe.audioTrack(url), name)
                let range = try await audio.load(.timeRange)

                #expect(abs(range.end.seconds - 2) <= 0.05, name)
                #expect(try await FilmProbe.loudness(url, from: 0, to: 1) > 0.001, name)
                #expect(try await FilmProbe.loudness(url, from: 1.5, to: 1.95) > 0.001, name)
            }
        }
    }
}
