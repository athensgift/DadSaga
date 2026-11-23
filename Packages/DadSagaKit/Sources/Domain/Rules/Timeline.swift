import Foundation

/// Something that happened, as shown in the timeline: a quest done, a boss beaten or a first captured.
public struct TimelineEntry: Hashable, Identifiable, Sendable {
    public enum Kind: Hashable, Sendable {
        case quest(Quest)
        case boss(BossFight)
        case first(FirstMoment)
    }

    /// The event it comes from.
    public let id: UUID
    /// The parent who recorded it (`ProgressEvent.authorID`).
    public let authorID: UUID
    public let kind: Kind
    public let childID: UUID
    public let date: Date
    public let note: String?
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]

    public var coverPhotoID: String? { photoIDs.first }

    public var xp: Int {
        switch kind {
        case .quest(let quest): quest.xp
        case .boss(let boss): boss.xp
        case .first(let first): first.xp
        }
    }
}

/// The family's history, derived from progress events. Pure and deterministic.
///
/// The one place that decides which events count, and for whom (ADR-0065 §3). Unknown content is skipped (e.g. removed
/// in an update), and an id from before a rename counts as the content's current id. The timeline lists every entry
/// of a card the content knows, whoever recorded it. A parent's standing counts a quest every time and a boss or a
/// first once per child for that parent (`countedEntries`, which `DadProgress` reads), so the timeline may list an
/// entry that counts for nothing. The family's story counts a first once per child, whoever captured it
/// (`familyEntries`).
public enum Timeline {
    /// Newest first: every entry of a card the content knows, whoever recorded it.
    public static func entries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        known(from: events, catalog: catalog).reversed()
    }

    /// Oldest first: what counts for each parent's standing. A quest every time, a boss or a first once per child for
    /// each author, the earlier.
    static func countedEntries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        var counted: Set<Once> = []
        return known(from: events, catalog: catalog).filter { entry in
            guard let content = entry.oncePerChildContent else { return true }
            return counted.insert(Once(childID: entry.childID, authorID: entry.authorID, content: content)).inserted
        }
    }

    /// Oldest first: the family's story, for the film and its occasions. A quest every time, a boss once per child for
    /// each parent who beat it (a boss is what a parent does), and a first once per child, the earlier capture,
    /// whoever captured it (a first is what a child does, ADR-0065 §3.3).
    static func familyEntries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        var counted: Set<Once> = []
        return countedEntries(from: events, catalog: catalog).filter { entry in
            guard case .first(let first) = entry.kind else { return true }
            return counted.insert(Once(childID: entry.childID, authorID: nil, content: .first(id: first.id))).inserted
        }
    }

    /// Oldest first, by the day it happened, then by id, so every iPhone of the family picks the same earlier entry:
    /// every event whose content the content knows, under its current id (ADR-0048 §5).
    private static func known(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        events.sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }.compactMap { event in
            let kind: TimelineEntry.Kind
            switch event.kind {
            case .quest(let id):
                guard let quest = catalog.quest(id: id) else { return nil }
                kind = .quest(quest)
            case .boss(let id):
                guard let boss = catalog.boss(id: id) else { return nil }
                kind = .boss(boss)
            case .first(let id):
                guard let first = catalog.first(id: id) else { return nil }
                kind = .first(first)
            }
            return TimelineEntry(
                id: event.id,
                authorID: event.authorID,
                kind: kind,
                childID: event.childID,
                date: event.date,
                note: event.note,
                photoIDs: event.photoIDs
            )
        }
    }

    /// One boss or first with one child, for one author, or for the family when `authorID` is `nil`.
    private struct Once: Hashable {
        let childID: UUID
        let authorID: UUID?
        let content: ProgressEvent.Kind
    }
}

extension TimelineEntry {
    /// The entry's card under its current id when it counts once per child; `nil` for a quest.
    fileprivate var oncePerChildContent: ProgressEvent.Kind? {
        switch kind {
        case .quest: nil
        case .boss(let boss): .boss(id: boss.id)
        case .first(let first): .first(id: first.id)
        }
    }
}
