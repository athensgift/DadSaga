/// The dad's RPG class. Purely an identity and a look: no class is stronger than another.
public struct HeroClass: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    public let order: Int
    public let title: LocalizedText
    public let tagline: LocalizedText
    /// Which drawing the avatar uses. An unknown look is drawn as Super Dad.
    public let look: String

    public init(
        id: String,
        order: Int,
        title: LocalizedText,
        tagline: LocalizedText,
        look: String,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.order = order
        self.title = title
        self.tagline = tagline
        self.look = look
    }
}
