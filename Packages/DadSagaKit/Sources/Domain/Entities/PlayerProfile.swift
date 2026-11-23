import Foundation

/// Who is playing: the dad's hero and look, and his children (the companions).
public struct PlayerProfile: Hashable, Identifiable, Sendable {
    /// The most children "My family" adds: an edit that adds a child is refused past it (`ProfileRules`). A family may
    /// hold more, from two parents adding at once or a copy, and can still be edited (ADR-0065 §4).
    public static let maxChildren = 4

    /// Who this player is: made once at onboarding, or brought by a copy (ADR-0065 §5). Every entry this player records
    /// carries it as its author. It never changes while the saga is on the iPhone.
    public let id: UUID
    /// The children in the family, in the order the dad entered them, at least one once validated. A child removed from
    /// the family is never here (ADR-0065 §4).
    public var children: [Child]
    /// The children removed from the family (ADR-0065 §4), in the order the dad entered them: listed on "My family"
    /// only, to bring back or delete for good, and in none of the family's counts (the picker, siblings, the limit of
    /// four). Their entries stay and still count for their author.
    public var removedChildren: [Child]
    public var heroClassID: String
    public var dadSkinTone: SkinTone
    /// The dad's hair, beard and glasses (ADR-0044).
    public var dadAppearance: DadAppearance
    /// "I have a partner" (ADR-0053 §4): shows the cards for the two of them. Yes unless he said no.
    public var hasPartner: Bool

    /// The child with `id`, or the first child when `id` is `nil` or no longer in the family. `nil` without children.
    public func child(_ id: UUID?) -> Child? {
        children.first { $0.id == id } ?? children.first
    }

    /// Without a look, the dad has the standard look for his skin tone.
    public init(
        id: UUID,
        children: [Child],
        heroClassID: String,
        dadSkinTone: SkinTone = .mediumLight,
        dadAppearance: DadAppearance? = nil,
        hasPartner: Bool = true,
        removedChildren: [Child] = []
    ) {
        self.id = id
        self.children = children
        self.heroClassID = heroClassID
        self.dadSkinTone = dadSkinTone
        self.dadAppearance = dadAppearance ?? .standard(for: dadSkinTone)
        self.hasPartner = hasPartner
        self.removedChildren = removedChildren
    }
}
