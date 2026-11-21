/// Who a card is for, when it isn't for every family (ADR-0053 §4). Facts about the family the dad gives, never about the
/// child's development (ADR-0006 rule 3).
public enum Audience: String, CaseIterable, Hashable, Sendable {
    /// The dad is raising the children with a partner.
    case partner
    /// The child has a sibling born before them.
    case olderSibling
    /// The child has a sibling born after them, or one on the way.
    case youngerSibling
}
