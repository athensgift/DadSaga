/// A "legendary moment" in the child's life. Celebrated when it happens, never expected by a date.
public struct FirstMoment: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    public let order: Int
    public let emoji: String
    public let title: LocalizedText
    /// XP for the dad for capturing the moment.
    public let xp: Int
    /// Visual change unlocked on the child's companion (e.g. "walk"), if any.
    public let companionTrait: String?
    /// A first before the birth, such as the day he found out (ADR-0053 §3): offered before the birth, and datable on any
    /// day up to today.
    public let isBeforeBirth: Bool
    /// A shipped first that is never offered again; it stays for the moments already captured (ADR-0053 §6).
    public let isRetired: Bool

    public init(
        id: String,
        order: Int,
        emoji: String,
        title: LocalizedText,
        xp: Int,
        companionTrait: String?,
        isBeforeBirth: Bool = false,
        isRetired: Bool = false,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.order = order
        self.emoji = emoji
        self.title = title
        self.xp = xp
        self.companionTrait = companionTrait
        self.isBeforeBirth = isBeforeBirth
        self.isRetired = isRetired
    }
}
