/// The four sides of what the dad does. Flavour ("your patience grew") and the name of a gear slot: a skill unlocks
/// nothing (ADR-0055 §1).
public enum Skill: String, CaseIterable, Hashable, Sendable {
    case care
    case play
    case patience
    /// The dad's own wellbeing. Research shows this is the most under-served need.
    case resilience
}
