/// A "legendary moment" in the child's life. Celebrated when it happens, never expected by a date.
public struct FirstMoment: Hashable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let emoji: String
    public let title: LocalizedText
    /// XP for the dad for capturing the moment.
    public let xp: Int
    /// Visual change unlocked on the child's companion (e.g. "walk"), if any.
    public let companionTrait: String?

    public init(id: String, order: Int, emoji: String, title: LocalizedText, xp: Int, companionTrait: String?) {
        self.id = id
        self.order = order
        self.emoji = emoji
        self.title = title
        self.xp = xp
        self.companionTrait = companionTrait
    }
}
