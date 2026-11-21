import Foundation

/// Who is playing: the dad's hero and look, and his children (the companions).
public struct PlayerProfile: Hashable, Sendable {
    public static let maxChildren = 4

    /// In the order the dad entered them. Always 1...`maxChildren` once validated.
    public var children: [Child]
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
        children: [Child],
        heroClassID: String,
        dadSkinTone: SkinTone = .mediumLight,
        dadAppearance: DadAppearance? = nil,
        hasPartner: Bool = true
    ) {
        self.children = children
        self.heroClassID = heroClassID
        self.dadSkinTone = dadSkinTone
        self.dadAppearance = dadAppearance ?? .standard(for: dadSkinTone)
        self.hasPartner = hasPartner
    }
}
