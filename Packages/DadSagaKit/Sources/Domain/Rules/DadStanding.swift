/// The dad's title and the gear it brings, from his entries and what the store kept (ADR-0055 §3, §4). Pure.
public struct DadStanding: Hashable, Sendable {
    /// The higher of the title his entries reach and the one kept. `nil` only without titles in the content.
    public let title: DadTitle?
    /// Every item his title and the titles below it bring, by slot, the best last in each (`GearRules.ordered`).
    public let gear: [GearItem]
    /// Set while his title is above the last one whose card he closed.
    public let news: TitleNews?
    /// The title to remember as the last card closed once an Undo has taken an entry back, when `progress` is his
    /// entries without it; `nil` when the closed card stays as it is. Only a card closed for a title above the one he
    /// still holds goes back, to that title. So a card closed for a title he still holds stays closed, and the card of
    /// a title the Undo took comes again when a card reaches it (ADR-0055 §3).
    public let seenAfterUndo: DadTitle?
    /// The title the store should keep before an entry is deleted for good, or `nil` when it already keeps it: the
    /// title he holds, when it is higher than the kept one. Recording keeps nothing, so an Undo takes back the title
    /// the entry brought by deleting it and nothing more.
    public let titleToKeep: DadTitle?

    public init(progress: DadProgress, catalog: ContentCatalog, kept: KeptStanding) {
        let reached = TitleRules.reached(cardsDone: progress.cardsDone, xp: progress.totalXP, in: catalog.titles)
        let keptTitle = kept.titleID.flatMap(catalog.title(id:))
        let title = [reached, keptTitle].compactMap(\.self).max { $0.order < $1.order }
        self.init(title: title, catalog: catalog, kept: kept)
    }

    /// The dad as he was when a film's period ended (ADR-0055 §9): the title his entries then reach, and its gear.
    /// `progress` holds only those entries.
    public static func asOf(_ progress: DadProgress, catalog: ContentCatalog) -> DadStanding {
        let title = TitleRules.reached(cardsDone: progress.cardsDone, xp: progress.totalXP, in: catalog.titles)
        return DadStanding(title: title, catalog: catalog, kept: KeptStanding(seenTitleID: title?.id))
    }

    private init(title: DadTitle?, catalog: ContentCatalog, kept: KeptStanding) {
        self.title = title
        gear = GearRules.ordered(
            Self.brought(by: catalog.titles.filter { $0.order <= title?.order ?? -1 }, in: catalog), in: catalog
        )
        let closed = kept.seenTitleID.flatMap(catalog.title(id:))
        if let title, let closed, closed.order > title.order { seenAfterUndo = title } else { seenAfterUndo = nil }
        let seen = closed ?? catalog.titles.first
        if let title, let seen, title.order > seen.order {
            let since = catalog.titles.filter { $0.order > seen.order && $0.order <= title.order }
            news = TitleNews(title: title, gear: Self.brought(by: since, in: catalog))
        } else {
            news = nil
        }
        titleToKeep = title.flatMap { title in kept.titleID.map(title.has(id:)) == true ? nil : title }
    }

    private static func brought(by titles: [DadTitle], in catalog: ContentCatalog) -> [GearItem] {
        titles.sorted { $0.order < $1.order }.flatMap { $0.gearIDs.compactMap(catalog.gearItem(id:)) }
    }
}

/// A title the dad hasn't seen the card for yet, and what the titles since his last card brought his hero.
public struct TitleNews: Hashable, Sendable {
    public let title: DadTitle
    /// Only items the hero didn't have before, in title order.
    public let gear: [GearItem]

    public init(title: DadTitle, gear: [GearItem]) {
        self.title = title
        self.gear = gear
    }
}
