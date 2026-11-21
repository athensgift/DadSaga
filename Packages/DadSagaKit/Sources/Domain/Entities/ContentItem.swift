/// Content stored events and choices point to by id (ADR-0048 §4). An id never goes away once shipped: a rename keeps
/// the old one in `formerIDs`, so what the dad recorded under it still counts.
public protocol ContentItem {
    var id: String { get }
    /// Ids this item had before a rename, oldest first.
    var formerIDs: [String] { get }
}

extension ContentItem {
    /// Whether `id` is this item's id now or was before a rename.
    public func has(id: String) -> Bool {
        self.id == id || formerIDs.contains(id)
    }
}
