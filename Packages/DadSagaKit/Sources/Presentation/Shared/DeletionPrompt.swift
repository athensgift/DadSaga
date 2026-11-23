import Foundation

/// The question asked before deleting something for good: an entry, or a child removed from the family.
public struct DeletionPrompt: Equatable, Identifiable, Sendable {
    /// What to delete: the entry, or the child.
    public let id: UUID
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String
}
