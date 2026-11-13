/// The four branches of the dad's skill tree.
public enum Skill: String, CaseIterable, Hashable, Sendable {
    case care
    case play
    case patience
    /// The dad's own wellbeing. Research shows this is the most under-served need.
    case resilience

    public var title: LocalizedText {
        switch self {
        case .care: LocalizedText(el: "Φροντίδα", en: "Care")
        case .play: LocalizedText(el: "Παιχνίδι", en: "Play")
        case .patience: LocalizedText(el: "Υπομονή", en: "Patience")
        case .resilience: LocalizedText(el: "Αντοχή", en: "Resilience")
        }
    }
}
