import Domain

extension ContentCatalog {
    /// Titles `t0`, `t1`, `t2` in that order and nothing else, for tests of what the store keeps (ADR-0055 §3).
    static let threeTitles = ContentCatalog(
        worlds: [], quests: [], bosses: [], firsts: [],
        titles: (0...2).map { order in
            DadTitle(
                id: "t\(order)", order: order, minCards: order, minXP: order * 20, name: LocalizedText(el: "x", en: "x")
            )
        }
    )
}
