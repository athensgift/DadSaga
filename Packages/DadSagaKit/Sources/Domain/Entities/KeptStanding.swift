/// What the store keeps so a deletion never lowers the title (ADR-0055 §3). The title only grows. The closed card goes
/// back only when an Undo takes back the title it was for. A new saga keeps nothing: `KeptStanding()`.
public struct KeptStanding: Hashable, Sendable {
    /// The highest title the dad held when he last deleted an entry. `nil` before any deletion.
    public var titleID: String?
    /// The title whose card he closed last, or the one he still held after an Undo took that title back
    /// (`DadStanding.seenAfterUndo`).
    public var seenTitleID: String?

    public init(titleID: String? = nil, seenTitleID: String? = nil) {
        self.titleID = titleID
        self.seenTitleID = seenTitleID
    }

    /// What is kept once `titleID` is kept too: the higher of the two titles, whatever the order they come in, since a
    /// kept title never goes down (ADR-0055 §3, ADR-0065 §4). A kept title the content doesn't know is never replaced:
    /// a newer version kept it, and only ever keeps a higher one; for the same reason one arriving is taken over a
    /// known one. Of two titles of the same rank, the kept one stays. `seenTitleID` is untouched.
    public func keeping(titleID other: String?, catalog: ContentCatalog) -> KeptStanding {
        guard let other, let current = titleID else {
            return KeptStanding(titleID: titleID ?? other, seenTitleID: seenTitleID)
        }
        guard let kept = catalog.title(id: current) else { return self }
        guard let arriving = catalog.title(id: other) else {
            return KeptStanding(titleID: other, seenTitleID: seenTitleID)
        }
        return arriving.order > kept.order ? KeptStanding(titleID: other, seenTitleID: seenTitleID) : self
    }
}
