/// What the hero wears in one gear slot (one per skill).
public enum OutfitChoice: Hashable, Sendable {
    /// The best item earned so far; changes by itself as the dad earns more. The default.
    case automatic
    /// Nothing in this slot.
    case hidden
    /// A specific earned item, by id.
    case item(String)
}

/// The dad's choices in the wardrobe. Slots without a choice are automatic.
public struct Outfit: Hashable, Sendable {
    public var choices: [Skill: OutfitChoice]

    public init(choices: [Skill: OutfitChoice] = [:]) {
        self.choices = choices
    }

    public func choice(for skill: Skill) -> OutfitChoice {
        choices[skill] ?? .automatic
    }
}
