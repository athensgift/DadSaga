/// All game content: worlds, quests, boss fights, legendary moments, hero classes and hero gear.
public struct ContentCatalog: Hashable, Sendable {
    public let worlds: [World]
    public let quests: [Quest]
    public let bosses: [BossFight]
    public let firsts: [FirstMoment]
    public let heroClasses: [HeroClass]
    public let gear: [GearItem]

    public init(
        worlds: [World],
        quests: [Quest],
        bosses: [BossFight],
        firsts: [FirstMoment],
        heroClasses: [HeroClass] = [],
        gear: [GearItem] = []
    ) {
        self.worlds = worlds.sorted { $0.order < $1.order }
        self.quests = quests
        self.bosses = bosses
        self.firsts = firsts.sorted { $0.order < $1.order }
        self.heroClasses = heroClasses.sorted { $0.order < $1.order }
        self.gear = gear
    }
}
