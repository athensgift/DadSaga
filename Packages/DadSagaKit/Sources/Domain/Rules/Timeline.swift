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
/// The one place that decides which events count: unknown content is skipped (e.g. removed in an update), an id from
/// before a rename counts as the content's current id, and a boss or first counts only the first time per child; quests
/// are repeatable. `DadProgress` is built from the same entries, so the timeline and the dad's XP can never disagree
/// (ADR-0017).
public enum Timeline {
    /// Newest first.
    public static func entries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        countedEntries(from: events, catalog: catalog).reversed()
    }

    /// Oldest first: every event that counts, with its content.
    static func countedEntries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        var counted: Set<OncePerChild> = []
        var entries: [TimelineEntry] = []

        for event in events.sorted(by: { $0.date < $1.date }) {
            // An event stored under a former id counts as its content's current id (ADR-0048 §4).
            guard let canonical = catalog.canonical(event.kind) else { continue }
            let kind: TimelineEntry.Kind
            switch event.kind {
            case .quest(let id):
                guard let quest = catalog.quest(id: id) else { continue }
                kind = .quest(quest)
            case .boss(let id):
                guard let boss = catalog.boss(id: id) else { continue }
                kind = .boss(boss)
            case .first(let id):
                guard let first = catalog.first(id: id) else { continue }
                kind = .first(first)
            }
            if canonical.countsOncePerChild,
               !counted.insert(OncePerChild(childID: event.childID, kind: canonical)).inserted { continue }
            entries.append(
                TimelineEntry(
                    id: event.id,
                    kind: kind,
                    childID: event.childID,
                    date: event.date,
                    note: event.note,
                    photoIDs: event.photoIDs
                )
            )
        }
        return entries
    }

    private struct OncePerChild: Hashable {
        let childID: UUID
        let kind: ProgressEvent.Kind
    }
}
