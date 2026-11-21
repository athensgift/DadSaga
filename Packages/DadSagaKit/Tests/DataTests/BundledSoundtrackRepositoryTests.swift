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

    @Test("Given the bundled content and music, when making the longest film the content allows, then every track outlasts it")
    func everyTrackOutlastsTheLongestFilm() async throws {
        let film = try await Self.longestFilm()

        for track in try await repository.fetchSoundtracks() {
            // Measured as `MusicBed` measures it before it decides to loop: exact timing, the audio track's own range.
            let asset = AVURLAsset(url: track.audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            let audio = try await asset.loadTracks(withMediaType: .audio)
            #expect(audio.count == 1, "\(track.id) has \(audio.count) audio tracks")
            let range = try await try #require(audio.first).load(.timeRange)

            #expect(
                range.duration.seconds >= film.seconds,
                "\(track.id) lasts \(range.duration.seconds) s, a film \(film.seconds) s"
            )
        }
    }

    /// The longest film the bundled content allows (ADR-0036 §2, ADR-0052): every first, each with all its photos, spread
    /// across the worlds so each can have its chapter card, under far more quests and bosses than fit. The film's own
    /// rules then drop everything but the firsts and shorten those, so it is as long as the content can make it.
    private static func longestFilm() async throws -> SagaStoryboard {
        let catalog = try await BundledContentRepository().fetchCatalog()
        let child = Child(name: "Test", birthDay: .day(2_020, 1, 15))
        let worlds = catalog.worlds
        let birth = try #require(child.birthDay)
        let photos = (1...ProgressEvent.photoLimit).map { "p\($0)" }
        let byID = Dictionary(uniqueKeysWithValues: worlds.map { ($0.id, $0) })
        /// A moment in the world: from its first month, or a month before the birth for the world before birth, so
        /// that world gets its chapter too (ADR-0053 §2).
        let inWorld = { (worldID: String, minute: Int) throws -> Date in
            let world = try #require(byID[worldID], "\(worldID) is a world")
            let start: CalendarDay = switch world.span {
            case .beforeBirth: birth.adding(days: -30)
            case .months(let min, _): try #require(child.day(atMonths: min))
            }
            return start.start(in: .gmt).addingTimeInterval(Double(60 * minute))
        }
        let lastMonths = worlds.compactMap { world -> Int? in
            if case .months(let min, _) = world.span { min } else { nil }
        }.max() ?? 0
        let firsts = try catalog.firsts.enumerated().map { index, first in
            ProgressEvent(
                kind: .first(id: first.id), childID: child.id,
                date: try inWorld(worlds[index % worlds.count].id, index), photoIDs: photos
            )
        }
        let quests = try catalog.quests.enumerated().map { index, quest in
            ProgressEvent(
                kind: .quest(id: quest.id), childID: child.id, date: try inWorld(quest.worldID, index), photoIDs: photos
            )
        }
        let bosses = try catalog.bosses.enumerated().map { index, boss in
            ProgressEvent(
                kind: .boss(id: boss.id), childID: child.id, date: try inWorld(boss.worldID, index), photoIDs: photos
            )
        }
        let film = try #require(SagaStoryboard.make(
            events: firsts + quests + bosses,
            child: child,
            period: .everything,
            catalog: catalog,
            now: birth.adding(months: lastMonths + 12).start(in: .gmt),
            timeZone: .gmt
        ))
        let keptFirsts = film.scenes.count { scene in
            if case .entry(let entry) = scene.kind, case .first = entry.kind { true } else { false }
        }
        #expect(keptFirsts == catalog.firsts.count, "a film keeps every first")
        let chapters = film.scenes.count { if case .chapter = $0.kind { true } else { false } }
        #expect(chapters == worlds.count, "every world has its chapter card, or the worst case is undercounted")
        return film
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
