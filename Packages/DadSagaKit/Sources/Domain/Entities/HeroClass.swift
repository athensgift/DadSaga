/// The dad's RPG class. Purely an identity and a look: no class is stronger than another.
public struct HeroClass: Hashable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let title: LocalizedText
    public let tagline: LocalizedText
    /// Which drawing the avatar uses. An unknown look is drawn as Super Dad.
    public let look: String

    public init(id: String, order: Int, title: LocalizedText, tagline: LocalizedText, look: String) {
        self.id = id
        self.order = order
        self.title = title
        self.tagline = tagline
        self.look = look
    }
}
