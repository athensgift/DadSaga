import Foundation
@testable import Presentation
import Testing

@Suite("Timeline preview")
struct TimelinePreviewTests {
    private static func item(_ title: String) -> TimelineItem {
        TimelineItem(
            id: UUID(), kind: .quest, title: title, subtitle: "", badge: "", symbol: "heart", photoIDs: [], photoCount: nil
        )
    }

    private static func content(_ months: [[TimelineItem]]) -> TimelineContent {
        TimelineContent(
            title: "",
            filters: [],
            selectedFilter: nil,
            sections: months.enumerated().map { TimelineSection(id: "\($0.offset)", title: "", items: $0.element) },
            emptyTitle: "",
            emptyMessage: "",
            filmTitle: nil,
            viewer: PhotoViewerLabels(locale: Locale(identifier: "en_US"))
        )
    }

    @Test("Given the dad has tapped no entry, when the timeline folds, then the newest entry stands above the fold")
    func newestFirst() {
        let newest = Self.item("Night shift")
        let content = Self.content([[newest, Self.item("Cuddle time")], [Self.item("First fever")]])
        #expect(content.previewed(id: nil) == newest)
    }

    @Test("Given the dad tapped an older entry, when the preview is shown, then it is that entry")
    func tappedEntry() {
        let older = Self.item("First fever")
        let content = Self.content([[Self.item("Night shift")], [older]])
        #expect(content.previewed(id: older.id) == older)
    }

    @Test("Given the tapped entry was deleted, when the preview is shown, then it is the newest entry left")
    func tappedEntryGone() {
        let newest = Self.item("Night shift")
        let content = Self.content([[newest]])
        #expect(content.previewed(id: UUID()) == newest)
    }

    @Test("Given an empty timeline, when it folds, then nothing stands above the fold")
    func emptyTimeline() {
        #expect(Self.content([]).previewed(id: nil) == nil)
    }
}
