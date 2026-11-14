import Domain

extension Skill {
    /// SF Symbol shown on cards for this skill branch.
    var symbol: String {
        switch self {
        case .care: "heart.fill"
        case .play: "puzzlepiece.fill"
        case .patience: "hourglass"
        case .resilience: "figure.mind.and.body"
        }
    }
}
