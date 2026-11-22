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
}
