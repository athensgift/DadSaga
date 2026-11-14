/// Who is playing: the dad's hero and look, and his children (the companions).
public struct PlayerProfile: Hashable, Sendable {
    public static let maxChildren = 4

    /// In the order the dad entered them. Always 1...`maxChildren` once validated.
    public var children: [Child]
    public var heroClassID: String
    public var dadSkinTone: SkinTone

    public init(children: [Child], heroClassID: String, dadSkinTone: SkinTone = .mediumLight) {
        self.children = children
        self.heroClassID = heroClassID
        self.dadSkinTone = dadSkinTone
    }
}
