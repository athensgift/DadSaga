/// The facts about a family that decide who a card is for (ADR-0053 §4): what the dad answered, and the order the
/// children were born in. Never the child's development (ADR-0006 rule 3).
public struct FamilyFacts: Hashable, Sendable {
    public let hasPartner: Bool
    /// Another child was born before this one; for a child not born yet, any born child. Twins have none.
    public let hasOlderSibling: Bool
    /// Another child was born after this one, or is on the way while this one is born.
    public let hasYoungerSibling: Bool

    public init(hasPartner: Bool, hasOlderSibling: Bool, hasYoungerSibling: Bool) {
        self.hasPartner = hasPartner
        self.hasOlderSibling = hasOlderSibling
        self.hasYoungerSibling = hasYoungerSibling
    }

    /// The facts for `child` in `profile`'s family.
    public init(profile: PlayerProfile, child: Child) {
        let others = profile.children.filter { $0.id != child.id }
        hasPartner = profile.hasPartner
        if let born = child.birthDay {
            hasOlderSibling = others.contains { $0.birthDay.map { $0 < born } ?? false }
            hasYoungerSibling = others.contains { $0.birthDay.map { $0 > born } ?? true }
        } else {
            hasOlderSibling = others.contains(where: \.isBorn)
            hasYoungerSibling = false
        }
    }

    public func holds(_ audience: Audience) -> Bool {
        switch audience {
        case .partner: hasPartner
        case .olderSibling: hasOlderSibling
        case .youngerSibling: hasYoungerSibling
        }
    }

    /// Whether a card for `audiences` is for this family: every one listed must hold.
    public func allows(_ audiences: Set<Audience>) -> Bool {
        audiences.allSatisfy(holds)
    }
}
