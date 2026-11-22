/// What the store keeps so a deletion never lowers the title and gear already earned stays (ADR-0055 §3, §4). Each
/// field only grows, except when an Undo puts back the record from before the card it takes back.
public struct KeptStanding: Hashable, Sendable {
    /// The highest title the dad held when his entries last changed. `nil` before any change.
    public var titleID: String?
    /// The gear the rule from before titles had earned him, frozen at his first change. `nil` until then: the rule
    /// still reads his entries, which are the ones from before titles.
    public var gearIDs: [String]?
    /// The title whose card he closed last.
    public var seenTitleID: String?

    public init(titleID: String? = nil, gearIDs: [String]? = nil, seenTitleID: String? = nil) {
        self.titleID = titleID
        self.gearIDs = gearIDs
        self.seenTitleID = seenTitleID
    }

    /// A saga started with titles: nothing from before to keep.
    public static let fresh = KeptStanding(gearIDs: [])
}

extension KeptStanding {
    /// What to keep once an Undo takes back an entry (ADR-0055 §3): the record from before it, `before`, with this one's
    /// closed card unless that is above the title he holds without the entry. Then it goes back only to the higher of
    /// that title and the card closed before, so a card he closed for a title he still holds stays closed, and one for
    /// the title the entry brought comes again when a card reaches it.
    /// - Parameter after: his entries without the one taken back.
    public func undone(to before: KeptStanding, after: DadProgress, catalog: ContentCatalog) -> KeptStanding {
        let held = DadStanding(progress: after, catalog: catalog, kept: before).title
        var next = before
        next.seenTitleID = seenTitleID
        guard let seen = seenTitleID.flatMap(catalog.title(id:)), seen.order > held?.order ?? -1 else { return next }
        let seenBefore = before.seenTitleID.flatMap(catalog.title(id:))
        next.seenTitleID = [held, seenBefore].compactMap(\.self).max { $0.order < $1.order }?.id
        return next
    }
}
