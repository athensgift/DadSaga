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
    public let childID: UUID?
    public let date: Date
    public let note: String?
    public let photoID: String?

    public var xp: Int {
        switch kind {
        case .quest(let quest): quest.xp
        case .boss(let boss): boss.xp
        case .first(let first): first.xp
        }
    }
}

/// The family's history, derived from progress events. Pure and deterministic.
public enum Timeline {
    /// Newest first. Follows the same rules as `DadProgress`: unknown content is skipped, and a boss or first counts
    /// only the first time per child, so the timeline never shows XP the dad did not get.
    public static func entries(from events: [ProgressEvent], catalog: ContentCatalog) -> [TimelineEntry] {
        let quests = Dictionary(uniqueKeysWithValues: catalog.quests.map { ($0.id, $0) })
        let bosses = Dictionary(uniqueKeysWithValues: catalog.bosses.map { ($0.id, $0) })
        let firsts = Dictionary(uniqueKeysWithValues: catalog.firsts.map { ($0.id, $0) })
        var counted: Set<OncePerChild> = []
        var entries: [TimelineEntry] = []

        for event in events.sorted(by: { $0.date < $1.date }) {
            let kind: TimelineEntry.Kind
            switch event.kind {
            case .quest(let id):
                guard let quest = quests[id] else { continue }
                kind = .quest(quest)
            case .boss(let id):
                guard let boss = bosses[id], counted.insert(OncePerChild(childID: event.childID, contentID: id)).inserted
                else { continue }
                kind = .boss(boss)
            case .first(let id):
                guard let first = firsts[id], counted.insert(OncePerChild(childID: event.childID, contentID: id)).inserted
                else { continue }
                kind = .first(first)
            }
            entries.append(
                TimelineEntry(
                    id: event.id,
                    kind: kind,
                    childID: event.childID,
                    date: event.date,
                    note: event.note,
                    photoID: event.photoID
                )
            )
        }
        return entries.reversed()
    }

    private struct OncePerChild: Hashable {
        let childID: UUID?
        let contentID: String
    }
}
