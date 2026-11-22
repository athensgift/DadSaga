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
