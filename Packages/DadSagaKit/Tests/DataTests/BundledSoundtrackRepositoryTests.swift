import Application
import AVFoundation
import Testing
@testable import Data
import SagaMusic

@Suite("BundledSoundtrackRepository")
struct BundledSoundtrackRepositoryTests {
    let repository = BundledSoundtrackRepository(bundle: SagaMusic.bundle)

    @Test("Given the bundled music, when fetching, then the original theme is credited and its file is bundled")
    func loadsTheTheme() async throws {
        let soundtracks = try await repository.fetchSoundtracks()

        #expect(soundtracks.map(\.id) == ["saga-theme"])
        let theme = try #require(soundtracks.first)
        #expect(theme.licence == .original)
        #expect(!theme.title.isEmpty)
        #expect(!theme.artist.isEmpty)
        #expect(FileManager.default.fileExists(atPath: theme.audioURL.path))
    }

    @Test("Given every bundled track, when opening it, then it has one audio track at least 95 seconds long")
    func everyTrackOutlastsAFilm() async throws {
        for track in try await repository.fetchSoundtracks() {
            let asset = AVURLAsset(url: track.audioURL)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)

            #expect(audio.count == 1, "\(track.id) has \(audio.count) audio tracks")
            #expect(duration.seconds >= 95, "\(track.id) lasts \(duration.seconds) s")
        }
    }

    @Test("Given a track DTO with a licence other than original or CC0, when mapping, then unknownLicence is thrown")
    func unknownLicence() {
        let dto = SoundtrackDTO(
            id: "t", file: "t.m4a", title: "T", artist: "A", licence: "CC-BY", source: "https://example.com"
        )
        #expect(throws: ContentDataError.unknownLicence(itemID: "t", licence: "CC-BY")) {
            try dto.toDomain(audioURL: URL(fileURLWithPath: "/t.m4a"))
        }
    }

    @Test("Given a CC0 track DTO, when mapping, then it keeps its credit and licence")
    func mapsCC0() throws {
        let dto = SoundtrackDTO(
            id: "t", file: "t.m4a", title: "Tune", artist: "Someone", licence: "cc0", source: "https://example.com"
        )
        let track = try dto.toDomain(audioURL: URL(fileURLWithPath: "/t.m4a"))

        #expect(track == Soundtrack(
            id: "t", title: "Tune", artist: "Someone", licence: .cc0, audioURL: URL(fileURLWithPath: "/t.m4a")
        ))
    }

    @Test("Given two tracks with the same id, when validating, then duplicateID is thrown")
    func duplicateID() {
        let track = Soundtrack(id: "dup", title: "T", artist: "A", licence: .original, audioURL: URL(fileURLWithPath: "/t"))
        #expect(throws: ContentDataError.duplicateID("dup")) {
            try ContentValidator.validate([track, track])
        }
    }

    @Test("Given a track with no title or artist, when validating, then emptyCredit is thrown")
    func emptyCredit() {
        let track = Soundtrack(id: "t", title: " ", artist: "A", licence: .cc0, audioURL: URL(fileURLWithPath: "/t"))
        #expect(throws: ContentDataError.emptyCredit(itemID: "t")) {
            try ContentValidator.validate([track])
        }
    }

    @Test("Given a file that isn't bundled, when looking it up, then missingResource is thrown")
    func missingFile() {
        #expect(throws: ContentDataError.missingResource("nope.m4a")) {
            try JSONResourceDataSource().url(of: "nope.m4a")
        }
    }
}
