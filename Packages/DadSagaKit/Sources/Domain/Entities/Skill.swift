/// The four branches of the dad's skill tree.
public enum Skill: String, CaseIterable, Hashable, Sendable {
    case care
    case play
    case patience
    /// The dad's own wellbeing. Research shows this is the most under-served need.
    case resilience
}
