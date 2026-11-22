/// Which title the dad's cards and XP reach (ADR-0055 §1).
public enum TitleRules {
    /// The highest title, by order, whose cards and XP are both reached. `nil` only when there are no titles.
    public static func reached(cardsDone: Int, xp: Int, in titles: [DadTitle]) -> DadTitle? {
        titles
            .filter { $0.minCards <= cardsDone && $0.minXP <= xp }
            .max { $0.order < $1.order }
    }
}
