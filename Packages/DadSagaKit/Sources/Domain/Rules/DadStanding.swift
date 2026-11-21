/// The dad's title and the gear he has, from his entries and what the store kept (ADR-0055 §3, §4). Pure.
public struct DadStanding: Hashable, Sendable {
    /// The higher of the title his entries reach and the one kept. `nil` only without titles in the content.
    public let title: DadTitle?
    /// Every item he has, by slot, the best last in each (`GearRules.ordered`).
    public let gear: [GearItem]
    /// Set while his title is above the last one whose card he closed.
    public let news: TitleNews?
    /// What the rule from before titles gave him, by id: kept, or read from his entries until it is.
    let gearBeforeTitles: [String]
    private let kept: KeptStanding

    public init(progress: DadProgress, catalog: ContentCatalog, kept: KeptStanding) {
        let reached = TitleRules.reached(cardsDone: progress.cardsDone, xp: progress.totalXP, in: catalog.titles)
        let keptTitle = kept.titleID.flatMap(catalog.title(id:))
        let title = [reached, keptTitle].compactMap(\.self).max { $0.order < $1.order }
        let before = kept.gearIDs.map { $0.compactMap(catalog.gearItem(id:)) }
            ?? GearRules.earnedBeforeTitles(catalog.gear, skillXP: progress.skillXP)
        self.init(title: title, before: before, catalog: catalog, kept: kept)
    }

    /// The dad as he was when a film's period ended (ADR-0055 §9): the title his entries then reach, and kept gear
    /// only where the rule from before titles had earned it by then. `progress` holds only those entries.
    public static func asOf(_ progress: DadProgress, catalog: ContentCatalog, kept: KeptStanding) -> DadStanding {
        let title = TitleRules.reached(cardsDone: progress.cardsDone, xp: progress.totalXP, in: catalog.titles)
        let then = GearRules.earnedBeforeTitles(catalog.gear, skillXP: progress.skillXP)
        let before = kept.gearIDs.map { ids in then.filter { item in ids.contains { item.has(id: $0) } } } ?? then
        return DadStanding(title: title, before: before, catalog: catalog, kept: KeptStanding(seenTitleID: title?.id))
    }

    private init(title: DadTitle?, before: [GearItem], catalog: ContentCatalog, kept: KeptStanding) {
        self.title = title
        self.kept = kept
        gearBeforeTitles = before.map(\.id)
        let byTitle = Self.brought(by: catalog.titles.filter { $0.order <= title?.order ?? -1 }, in: catalog)
        let byTitleIDs = Set(byTitle.map(\.id))
        gear = GearRules.ordered(byTitle + before.filter { !byTitleIDs.contains($0.id) }, in: catalog)
        let seen = kept.seenTitleID.flatMap(catalog.title(id:)) ?? catalog.titles.first
        if let title, let seen, title.order > seen.order {
            let since = catalog.titles.filter { $0.order > seen.order && $0.order <= title.order }
            let had = Set(gearBeforeTitles)
            news = TitleNews(title: title, gear: Self.brought(by: since, in: catalog).filter { !had.contains($0.id) })
        } else {
            news = nil
        }
    }

    /// What the store should keep now that the entries are about to change, or `nil` when it already keeps it: the
    /// title when it is higher, and the gear from before titles the first time.
    public var toKeep: KeptStanding? {
        let titleIsNew = title.map { title in kept.titleID.map { !title.has(id: $0) } ?? true } ?? false
        guard titleIsNew || kept.gearIDs == nil else { return nil }
        var next = kept
        next.titleID = title?.id ?? kept.titleID
        next.gearIDs = kept.gearIDs ?? gearBeforeTitles
        return next
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
