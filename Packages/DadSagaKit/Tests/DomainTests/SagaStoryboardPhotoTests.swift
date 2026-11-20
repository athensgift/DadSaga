import Domain
import Foundation
import Testing

/// An entry's further photos in the film, and how they are thinned (ADR-0042 §6).
@Suite("SagaStoryboard, further photos")
struct SagaStoryboardPhotoTests {
    let saga = SagaFixtures()

    @Test("Given quests with further photos that don't fit, when making the film, then further photos go before covers")
    func furtherPhotosThinnedBeforeQuestCovers() throws {
        let quests = (0..<20).map { saga.event(.quest(id: "q1"), months: 0, days: $0, photos: "c\($0)", "m\($0)") }

        let storyboard = try #require(saga.storyboard(quests))

        #expect(storyboard.seconds <= 90)
        #expect(storyboard.scenes.count { if case .entry = $0.kind { true } else { false } } == 20)
        Self.expectSpreadEvenly(Self.furtherPhotoIDs(in: storyboard), among: (0..<20).map { "m\($0)" })
    }

    @Test("Given firsts with many photos that don't fit, when making the film, then further photos go, never a card")
    func furtherPhotosThinnedBeforeFirstsShorten() throws {
        let firsts = (1...15).map {
            saga.event(.first(id: "f\($0)"), months: 0, days: $0, photos: "a\($0)", "b\($0)", "c\($0)", "d\($0)")
        }

        let storyboard = try #require(saga.storyboard(firsts))
        let cards = storyboard.scenes.filter { if case .entry = $0.kind { true } else { false } }

        #expect(cards.count == 15)
        #expect(cards.allSatisfy { $0.seconds == 4.5 })
        #expect(storyboard.seconds <= 90)
        Self.expectSpreadEvenly(
            Self.furtherPhotoIDs(in: storyboard), among: (1...15).flatMap { ["b\($0)", "c\($0)", "d\($0)"] }
        )
    }

    private static func furtherPhotoIDs(in storyboard: SagaStoryboard) -> [String] {
        storyboard.scenes.compactMap { if case .photo(_, let id) = $0.kind { id } else { nil } }
    }

    /// Some but not all of `all` were kept, in order, the first and the last among them, with even gaps.
    private static func expectSpreadEvenly(
        _ kept: [String], among all: [String], sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let index = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1, $0) })
        let positions = kept.compactMap { index[$0] }
        let gaps = zip(positions.dropFirst(), positions).map { $0 - $1 }
        #expect(positions.count == kept.count, sourceLocation: sourceLocation)
        #expect(kept.count > 1 && kept.count < all.count, sourceLocation: sourceLocation)
        #expect(kept.first == all.first && kept.last == all.last, sourceLocation: sourceLocation)
        #expect(gaps.allSatisfy { $0 > 0 }, sourceLocation: sourceLocation)
        #expect((gaps.max() ?? 0) - (gaps.min() ?? 0) <= 1, sourceLocation: sourceLocation)
    }
}
