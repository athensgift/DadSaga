/// Who is playing: the child (the companion) and the hero class the dad picked.
public struct PlayerProfile: Hashable, Sendable {
    public var child: Child
    public var heroClassID: String

    public init(child: Child, heroClassID: String) {
        self.child = child
        self.heroClassID = heroClassID
    }
}
