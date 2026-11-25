import Domain
import Foundation
import Testing

/// Which of an entry's further photos fill its places in the film, by the device's rating (ADR-0047 §2).
@Suite("SagaStoryboard, choosing further photos")
struct SagaStoryboardPhotoChoiceTests {
    let saga = SagaFixtures()

    @Test("Given a first with four further photos, when rated, then the best three play in the dad's order")
    func bestThreeInOrder() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b", "c", "d")
        ]))
        let ratings = ["a": rating(0.9), "b": rating(-0.5), "c": rating(0.1), "d": rating(0.4)]

        let chosen = storyboard.choosingPhotos(by: ratings)

        #expect(storyboard.photoChoices().map(\.candidates) == [["a", "b", "c", "d"]])
        #expect(Self.photoIDs(in: storyboard) == ["a", "b", "c"])
        #expect(Self.photoIDs(in: chosen) == ["a", "c", "d"])
        #expect(chosen.seconds == storyboard.seconds)
        #expect(chosen.scenes.map(\.seconds) == storyboard.scenes.map(\.seconds))
    }

    @Test("Given a utility photo, when places are short, then it goes first, whatever its score")
    func utilityGoesFirst() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b", "c", "d")
        ]))
        let ratings = [
            "a": rating(0.9, utility: true), "b": rating(-0.5), "c": rating(0.1), "d": rating(0.4)
        ]

        #expect(Self.photoIDs(in: storyboard.choosingPhotos(by: ratings)) == ["b", "c", "d"])
    }

    @Test("Given every further photo fits, when rated, then nothing is chosen and utility photos play")
    func nothingToChooseWhenAllFit() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b")
        ]))

        let chosen = storyboard.choosingPhotos(by: ["a": rating(-1, utility: true), "b": rating(1)])

        #expect(storyboard.photoChoices().isEmpty)
        #expect(chosen == storyboard)
    }

    @Test("Given no ratings, equal ratings or one unrated photo, when choosing, then the film is today's")
    func missingOrEqualRatingsKeepToday() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b", "c", "d")
        ]))
        let same = rating(0.2)

        #expect(storyboard.choosingPhotos(by: [:]) == storyboard)
        #expect(storyboard.choosingPhotos(by: ["a": same, "b": same, "c": same, "d": same]) == storyboard)
        #expect(storyboard.choosingPhotos(by: ["a": rating(-1), "b": rating(-1), "c": rating(1)]) == storyboard)
    }

    @Test("Given a long film, when rated, then each entry keeps as many photos and the cover is never replaced")
    func thinnedEntriesKeepTheirPlaces() throws {
        let firsts = (1...15).map {
            saga.event(.first(id: "f\($0)"), months: 0, days: $0, photos: "a\($0)", "b\($0)", "c\($0)", "d\($0)")
        }
        let storyboard = try #require(saga.storyboard(firsts))
        let ratings = Dictionary(uniqueKeysWithValues: (1...15).flatMap { day in
            [("b\(day)", rating(-0.5)), ("c\(day)", rating(0)), ("d\(day)", rating(0.5))]
        })

        let chosen = storyboard.choosingPhotos(by: ratings)

        #expect(chosen.scenes.map(\.seconds) == storyboard.scenes.map(\.seconds))
        #expect(Self.photoCounts(in: chosen) == Self.photoCounts(in: storyboard))
        #expect(Self.photoIDs(in: chosen).allSatisfy { !$0.hasPrefix("a") })
        for choice in storyboard.photoChoices() where choice.chosen.count == 1 {
            let day = choice.candidates[0].dropFirst()
            #expect(Self.photoIDs(in: chosen).contains("d\(day)"))
        }
    }

    // MARK: Photos that can't be read (ADR-0075)

    @Test("Given a further photo that can't be read, when choosing unrated, then the next readable one takes its place")
    func unreadableGivesItsPlace() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b", "c", "d")
        ]))

        let chosen = storyboard.choosingPhotos(by: [:], leavingOut: ["b"])

        #expect(storyboard.photosShownAlone == ["a", "b", "c", "d"])
        #expect(storyboard.photoChoices(leavingOut: ["b"]).isEmpty)
        #expect(Self.photoIDs(in: chosen) == ["a", "c", "d"])
        #expect(chosen.scenes.map(\.seconds) == storyboard.scenes.map(\.seconds))
    }

    @Test("Given a photo that can't be read, when rated best all the same, then it is never chosen")
    func unreadableIsNeverChosen() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b", "c", "d", "e")
        ]))
        let ratings = ["a": rating(1), "b": rating(-0.5), "c": rating(0.1), "d": rating(0.4), "e": rating(0.2)]

        let chosen = storyboard.choosingPhotos(by: ratings, leavingOut: ["a"])

        #expect(storyboard.photoChoices(leavingOut: ["a"]).map(\.candidates) == [["b", "c", "d", "e"]])
        #expect(Self.photoIDs(in: chosen) == ["c", "d", "e"])
    }

    @Test("Given fewer readable photos than places, when choosing, then the places left over go and the film is shorter")
    func placesWithoutAPhotoGo() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a", "b"),
            saga.event(.first(id: "f2"), months: 1, photos: "cover2", "x")
        ]))

        let chosen = storyboard.choosingPhotos(by: [:], leavingOut: ["a", "x"])

        #expect(Self.photoIDs(in: chosen) == ["b"])
        #expect(chosen.seconds == storyboard.seconds - 5)
        #expect(chosen.scenes.count == storyboard.scenes.count - 2)
    }

    @Test("Given a quest whose cover can't be read, when choosing, then its scene goes and its further photos stay")
    func questWithoutItsCover() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.quest(id: "q1"), months: 0, photos: "cover", "a"),
            saga.event(.first(id: "f1"), months: 1, photos: "first")
        ]))

        let chosen = storyboard.choosingPhotos(by: [:], leavingOut: ["cover", "first"])

        #expect(storyboard.photosShownAlone == ["cover", "a"])
        #expect(Self.photoIDs(in: chosen) == ["a"])
        // The first keeps its scene: its words stay on the dark (ADR-0037 §2).
        #expect(chosen.scenes.count == storyboard.scenes.count - 1)
        #expect(chosen.scenes.contains { if case .entry(let entry) = $0.kind { entry.photoIDs == ["first"] } else { false } })
    }

    @Test("Given three worlds and the middle one's only scene left out, when choosing, then its chapter goes too")
    func emptiedChapterGoes() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0),
            saga.event(.quest(id: "q1"), months: 10, photos: "gone"),
            saga.event(.first(id: "f2"), months: 30)
        ]))

        let chosen = storyboard.choosingPhotos(by: [:], leavingOut: ["gone"])

        #expect(Self.chapters(in: storyboard) == ["w1": 1, "w2": 2, "w3": 3])
        #expect(Self.chapters(in: chosen) == ["w1": 1, "w3": 2])
    }

    @Test("Given two worlds and one left without a scene, when choosing, then the film has no chapter card")
    func oneWorldLeftHasNoChapters() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0),
            saga.event(.quest(id: "q1"), months: 10, photos: "gone")
        ]))

        let chosen = storyboard.choosingPhotos(by: [:], leavingOut: ["gone"])

        #expect(Self.chapters(in: storyboard).count == 2)
        #expect(Self.chapters(in: chosen).isEmpty)
        #expect(chosen.scenes.count == 3)
    }

    @Test("Given no photo shown alone is unreadable, when choosing, then the film is the same")
    func nothingUnreadable() throws {
        let storyboard = try #require(saga.storyboard([
            saga.event(.first(id: "f1"), months: 0, photos: "cover", "a"),
            saga.event(.quest(id: "q1"), months: 10, photos: "quest")
        ]))

        #expect(storyboard.choosingPhotos(by: [:], leavingOut: []) == storyboard)
        #expect(storyboard.choosingPhotos(by: [:], leavingOut: ["cover", "elsewhere"]) == storyboard)
    }

    private static func chapters(in storyboard: SagaStoryboard) -> [String: Int] {
        storyboard.scenes.reduce(into: [:]) { chapters, scene in
            if case .chapter(let world, let number) = scene.kind { chapters[world.id] = number }
        }
    }

    private func rating(_ score: Double, utility: Bool = false) -> PhotoRating {
        PhotoRating(score: score, isUtility: utility)
    }

    private static func photoIDs(in storyboard: SagaStoryboard) -> [String] {
        storyboard.scenes.compactMap { if case .photo(_, let id) = $0.kind { id } else { nil } }
    }

    private static func photoCounts(in storyboard: SagaStoryboard) -> [UUID: Int] {
        storyboard.scenes.reduce(into: [:]) { counts, scene in
            if case .photo(let entry, _) = scene.kind { counts[entry.id, default: 0] += 1 }
        }
    }
}
