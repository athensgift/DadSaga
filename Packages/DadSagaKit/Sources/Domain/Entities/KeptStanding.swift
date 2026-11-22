/// What the store keeps so a deletion never lowers the title and gear already earned stays (ADR-0055 §3, §4). The
/// title and the gear only grow. The closed card goes back only when an Undo takes back the title it was for.
public struct KeptStanding: Hashable, Sendable {
    /// The highest title the dad held when he last deleted an entry. `nil` before any deletion.
    public var titleID: String?
    /// The gear the rule from before titles had earned him, frozen at his first change. `nil` until then: the rule
    /// still reads his entries, which are the ones from before titles.
    public var gearIDs: [String]?
    /// The title whose card he closed last, or the one he still held after an Undo took that title back
    /// (`DadStanding.seenAfterUndo`).
    public var seenTitleID: String?

    public init(titleID: String? = nil, gearIDs: [String]? = nil, seenTitleID: String? = nil) {
        self.titleID = titleID
        self.gearIDs = gearIDs
        self.seenTitleID = seenTitleID
    }

    /// A saga started with titles: nothing from before to keep.
    public static let fresh = KeptStanding(gearIDs: [])
}
