import Domain
import Foundation
import Testing

/// Which of an entry's further photos fill its places in the film, by the device's rating (ADR-0046 §2).
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

        #expect(storyboard.photoChoices.map(\.candidates) == [["a", "b", "c", "d"]])
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

        #expect(storyboard.photoChoices.isEmpty)
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
        for choice in storyboard.photoChoices where choice.chosen.count == 1 {
            let day = choice.candidates[0].dropFirst()
            #expect(Self.photoIDs(in: chosen).contains("d\(day)"))
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
