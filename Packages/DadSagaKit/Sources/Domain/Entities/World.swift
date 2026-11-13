/// A themed stage of childhood. Unlocks by the child's real age, never by performance.
public struct World: Hashable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let title: LocalizedText
    public let tagline: LocalizedText
    public let minAgeMonths: Int
    /// `nil` means open-ended.
    public let maxAgeMonths: Int?

    public init(
        id: String,
        order: Int,
        title: LocalizedText,
        tagline: LocalizedText,
        minAgeMonths: Int,
        maxAgeMonths: Int?
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.tagline = tagline
        self.minAgeMonths = minAgeMonths
        self.maxAgeMonths = maxAgeMonths
    }
}
