import AVFoundation
import FilmKit
import FilmTestSupport
import Foundation
import Testing

extension FilmKitTests {
    @Suite("Format")
    struct FormatTests {
        let encoder = FilmEncoder()

        @Test(
            "Given three clips of 30 frames, when encoding, then the film lasts exactly 3 s at 30 fps in its own size",
            arguments: [Fixture.portrait, Fixture.landscape]
        )
        func durationFramesAndSize(spec: FilmSpec) async throws {
            let url = try await Fixture.encode(Fixture.solidFilm([Fixture.red, Fixture.green, Fixture.blue], spec: spec))
            defer { try? FileManager.default.removeItem(at: url) }

            let track = try #require(try await FilmProbe.videoTrack(url))
            #expect(try await AVURLAsset(url: url).load(.duration) == CMTime(value: 90, timescale: 30))
            #expect(try await FilmProbe.frameCount(url) == 90)
            #expect(try await track.load(.naturalSize) == CGSize(width: spec.width, height: spec.height))
            #expect(abs(try await track.load(.nominalFrameRate) - 30) < 0.01)
        }

        @Test("Given a film, when encoding, then its video is H.264 High, tagged BT.709")
        func videoFormat() async throws {
            let url = try await Fixture.encode(Fixture.solidFilm([Fixture.red], frames: 10))
            defer { try? FileManager.default.removeItem(at: url) }

            let format = try #require(try await FilmProbe.videoFormat(url))

            #expect(format.isH264)
            #expect(format.profile == 100)
            #expect(format.primaries == kCMFormatDescriptionColorPrimaries_ITU_R_709_2 as String)
            #expect(format.transfer == kCMFormatDescriptionTransferFunction_ITU_R_709_2 as String)
            #expect(format.matrix == kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String)
        }

        @Test("Given a file already at the destination, when encoding, then the film replaces it")
        func replacesWhatWasThere() async throws {
            let url = Fixture.temporaryURL()
            try Data("not a film".utf8).write(to: url)
            defer { try? FileManager.default.removeItem(at: url) }

            try await encoder.encode(Fixture.solidFilm([Fixture.blue], frames: 10), to: url)

            #expect(try await FilmProbe.frameCount(url) == 10)
        }

        @Test("Given twenty small films in a row, when encoding them, then every one completes")
        func manyInARow() async throws {
            for index in 0..<20 {
                let url = try await Fixture.encode(Fixture.solidFilm([Fixture.blue], frames: 10))
                #expect(try await FilmProbe.frameCount(url) == 10, "film \(index)")
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
