/// A themed stage of childhood. Unlocks by the child's real age, never by performance.
public struct World: ContentItem, Hashable, Identifiable, Sendable {
    public let id: String
    /// Ids it had before a rename (ADR-0048 §5).
    public let formerIDs: [String]
    public let order: Int
    public let title: LocalizedText
    public let tagline: LocalizedText
    /// The ages it is for: the time before birth, or a range of months.
    public let span: WorldSpan

    public init(
        id: String,
        order: Int,
        title: LocalizedText,
        tagline: LocalizedText,
        span: WorldSpan,
        formerIDs: [String] = []
    ) {
        self.id = id
        self.formerIDs = formerIDs
        self.order = order
        self.title = title
        self.tagline = tagline
        self.span = span
    }

    /// Whether the world is before birth (ADR-0051 §2).
    public var isBeforeBirth: Bool { span == .beforeBirth }
}

/// The ages a world is for (ADR-0051 §2).
public enum WorldSpan: Hashable, Sendable {
    /// The time before the birth. Reached at every age: the current world before the birth, a visited one after it.
    case beforeBirth
    /// From `min` completed months; `max` is the last month in it, `nil` for open-ended.
    case months(min: Int, max: Int?)

    /// Whether a child of this age has reached the world.
    public func isReached(at age: ChildAge) -> Bool {
        switch (self, age) {
        case (.beforeBirth, _): true
        case (.months, .beforeBirth): false
        case (.months(let min, _), .months(let months)): min <= months
        }
    }
}
