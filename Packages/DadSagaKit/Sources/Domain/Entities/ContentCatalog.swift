/// All game content: worlds, quests, boss fights, legendary moments, hero classes, hero gear and the names of the
/// dad's look options.
public struct ContentCatalog: Hashable, Sendable {
    public let worlds: [World]
    public let quests: [Quest]
    public let bosses: [BossFight]
    public let firsts: [FirstMoment]
    public let heroClasses: [HeroClass]
    public let gear: [GearItem]
    /// In the order the menus show them.
    public let appearanceOptions: [DadAppearanceOption]
    /// Every current and former id of each kind, so an id stored before a rename still finds its item (ADR-0048 §5).
    private let questsByID: [String: Quest]
    private let bossesByID: [String: BossFight]
    private let firstsByID: [String: FirstMoment]
    private let worldsByID: [String: World]
    private let gearByID: [String: GearItem]
    private let heroesByID: [String: HeroClass]

    public init(
        worlds: [World],
        quests: [Quest],
        bosses: [BossFight],
        firsts: [FirstMoment],
        heroClasses: [HeroClass] = [],
        gear: [GearItem] = [],
        appearanceOptions: [DadAppearanceOption] = []
    ) {
        self.worlds = worlds.sorted { $0.order < $1.order }
        self.quests = quests
        self.bosses = bosses
        self.firsts = firsts.sorted { $0.order < $1.order }
        self.heroClasses = heroClasses.sorted { $0.order < $1.order }
        self.gear = gear
        self.appearanceOptions = appearanceOptions
        questsByID = Self.index(quests)
        bossesByID = Self.index(bosses)
        firstsByID = Self.index(firsts)
        worldsByID = Self.index(worlds)
        gearByID = Self.index(gear)
        heroesByID = Self.index(heroClasses)
    }

    public func quest(id: String) -> Quest? { questsByID[id] }
    public func boss(id: String) -> BossFight? { bossesByID[id] }
    public func first(id: String) -> FirstMoment? { firstsByID[id] }
    public func world(id: String) -> World? { worldsByID[id] }
    public func gearItem(id: String) -> GearItem? { gearByID[id] }
    public func heroClass(id: String) -> HeroClass? { heroesByID[id] }

    /// The dad's hero. A stored id the content no longer knows shows as the first hero: no error and nothing to choose
    /// again (ADR-0006). The stored id changes only when the dad changes something on "Your hero".
    public func hero(for profile: PlayerProfile) -> HeroClass? {
        heroClass(id: profile.heroClassID) ?? heroClasses.first
    }

    /// The kind with the content's current id, or `nil` when the catalog has no such content.
    public func canonical(_ kind: ProgressEvent.Kind) -> ProgressEvent.Kind? {
        switch kind {
        case .quest(let id): quest(id: id).map { .quest(id: $0.id) }
        case .boss(let id): boss(id: id).map { .boss(id: $0.id) }
        case .first(let id): first(id: id).map { .first(id: $0.id) }
        }
    }

    /// The first item wins an id: the validator rejects content where two share one.
    private static func index<Item: ContentItem>(_ items: [Item]) -> [String: Item] {
        var byID: [String: Item] = [:]
        for item in items {
            for id in [item.id] + item.formerIDs where byID[id] == nil {
                byID[id] = item
            }
        }
        return byID
    }
}
