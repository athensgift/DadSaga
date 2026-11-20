import Application
import AVFoundation
import Domain
import Testing
@testable import Data
import SagaMusic

@Suite("BundledSoundtrackRepository")
struct BundledSoundtrackRepositoryTests {
    let repository = BundledSoundtrackRepository(bundle: SagaMusic.bundle)

    @Test("Given the bundled music, when fetching, then the five original tracks are titled in el and en, and bundled")
    func loadsTheFive() async throws {
        let soundtracks = try await repository.fetchSoundtracks()

        #expect(soundtracks.map(\.id) == [
            "saga-theme", "candles-and-confetti", "music-box-lullaby", "great-adventure", "like-yesterday"
        ])
        for track in soundtracks {
            #expect(track.licence == .original, "\(track.id)")
            #expect(track.artist == "DadSaga", "\(track.id)")
            let texts = [track.title.el, track.title.en, track.mood.el, track.mood.en]
            #expect(texts.allSatisfy { !$0.isEmpty }, "\(track.id)")
            #expect(FileManager.default.fileExists(atPath: track.audioURL.path), "\(track.id)")
        }
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
            id: "t", file: "t.m4a", title: LocalizedTextDTO(el: "T", en: "T"), mood: LocalizedTextDTO(el: "M", en: "M"),
            artist: "A", licence: "CC-BY", source: "https://example.com"
        )
        #expect(throws: ContentDataError.unknownLicence(itemID: "t", licence: "CC-BY")) {
            try dto.toDomain(audioURL: URL(fileURLWithPath: "/t.m4a"))
        }
    }

    @Test("Given a CC0 track DTO, when mapping, then it keeps its bilingual title and mood, credit and licence")
    func mapsCC0() throws {
        let dto = SoundtrackDTO(
            id: "t",
            file: "t.m4a",
            title: LocalizedTextDTO(el: "Tune", en: "Tune"),
            mood: LocalizedTextDTO(el: "Ήρεμο", en: "Calm"),
            artist: "Someone",
            licence: "cc0",
            source: "https://example.com"
        )
        let track = try dto.toDomain(audioURL: URL(fileURLWithPath: "/t.m4a"))

        #expect(track == Soundtrack(
            id: "t",
            title: LocalizedText(el: "Tune", en: "Tune"),
            mood: LocalizedText(el: "Ήρεμο", en: "Calm"),
            artist: "Someone",
            licence: .cc0,
            audioURL: URL(fileURLWithPath: "/t.m4a")
        ))
    }

    static func track(
        id: String = "t",
        title: LocalizedText = LocalizedText(el: "Τ", en: "T"),
        mood: LocalizedText = LocalizedText(el: "Μ", en: "M"),
        artist: String = "A"
    ) -> Soundtrack {
        Soundtrack(id: id, title: title, mood: mood, artist: artist, licence: .cc0, audioURL: URL(fileURLWithPath: "/t"))
    }

    @Test("Given two tracks with the same id, when validating, then duplicateID is thrown")
    func duplicateID() {
        let track = Self.track(id: "dup")
        #expect(throws: ContentDataError.duplicateID("dup")) {
            try ContentValidator.validate([track, track])
        }
    }

    @Test(
        "Given a track with an empty Greek title, English mood or a blank artist, when validating, then emptyText is thrown",
        arguments: [
            track(title: LocalizedText(el: "", en: "T")),
            track(mood: LocalizedText(el: "Μ", en: " ")),
            track(artist: " \n")
        ]
    )
    func emptyText(track: Soundtrack) {
        #expect(throws: ContentDataError.emptyText(itemID: "t")) {
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
