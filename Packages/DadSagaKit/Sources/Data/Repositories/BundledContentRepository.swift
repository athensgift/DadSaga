import Application
import Domain

public enum ContentDataError: Error, Equatable {
    case missingResource(String)
    case unknownSkill(itemID: String, skill: String)
    case duplicateID(String)
    case unknownWorld(itemID: String, worldID: String)
    case emptyTip(itemID: String)
    /// A tip with more steps than `ContentValidator.maxTipSteps` (ADR-0073).
    case longTip(itemID: String)
    /// A boss with no survival guide.
    case emptyGuide(itemID: String)
    /// A card or first whose XP isn't above 0.
    case invalidXP(itemID: String)
    case unknownLicence(itemID: String, licence: String)
    case emptyText(itemID: String)
    /// A look option whose part or id the app cannot draw.
    case unknownAppearanceOption(part: String, id: String)
    /// A look option the app can draw that the content does not name.
    case missingAppearanceOption(part: String, id: String)
    /// An `onlyFor` word that is not an `Audience` (ADR-0053 §4).
    case unknownAudience(itemID: String, audience: String)
    /// A world neither before birth without ages, nor with a minimum age (ADR-0053 §7).
    case invalidWorldAges(worldID: String)
    /// A world whose ages don't start the month after the world before it ends, the first one at 0.
    case worldAgesNotInARow(worldID: String)
    /// A second world before birth, or one that isn't the first world by order.
    case misplacedBeforeBirthWorld(worldID: String)
    /// A card in the world before birth with a minimum age above 0 months.
    case agedBeforeBirth(itemID: String)
    /// A world with quests of its own, none of which may be the weekly quest (ADR-0082 §3).
    case noWeeklyQuest(worldID: String)
    /// Title orders that don't run 0, 1, 2… without a gap or a repeat: the order is the dad's level (ADR-0059 §1).
    case invalidTitleOrder(titleID: String)
    /// A skill `skills.json` doesn't give a curve (ADR-0059 §2).
    case missingSkillCurve(skill: String)
    /// A skill curve whose `halfGrownXP` isn't above 0.
    case invalidSkillCurve(skill: String)
    /// Titles whose first needs anything, or one that doesn't need more cards and more XP than the one before
    /// (ADR-0055 §2).
    case invalidTitleThresholds(titleID: String)
    /// A title brings an item the content doesn't have.
    case unknownGear(titleID: String, gearID: String)
    /// No title brings the item.
    case gearWithoutTitle(gearID: String)
    /// Two titles bring the item.
    case gearInTwoTitles(gearID: String)
}

/// `ContentRepository` backed by the JSON bundled with the app. The catalog is loaded and validated once.
public actor BundledContentRepository: ContentRepository {
    private let dataSource: JSONResourceDataSource
    private var cached: ContentCatalog?

    public init(dataSource: JSONResourceDataSource = JSONResourceDataSource()) {
        self.dataSource = dataSource
    }

    public func fetchCatalog() async throws -> ContentCatalog {
        if let cached { return cached }
        let catalog = ContentCatalog(
            worlds: try dataSource.decode([WorldDTO].self, resource: "worlds").map { try $0.toDomain() },
            quests: try dataSource.decode([QuestDTO].self, resource: "quests").map { try $0.toDomain() },
            bosses: try dataSource.decode([BossFightDTO].self, resource: "bosses").map { try $0.toDomain() },
            firsts: try dataSource.decode([FirstMomentDTO].self, resource: "firsts").map { $0.toDomain() },
            heroClasses: try dataSource.decode([HeroClassDTO].self, resource: "heroes").map { $0.toDomain() },
            gear: try dataSource.decode([GearItemDTO].self, resource: "gear").map { try $0.toDomain() },
            titles: try dataSource.decode([DadTitleDTO].self, resource: "titles").map { $0.toDomain() },
            skillCurves: try dataSource.decode([SkillCurveDTO].self, resource: "skills").map { try $0.toDomain() },
            appearanceOptions: try dataSource.decode([AppearanceOptionDTO].self, resource: "appearance")
                .map { try $0.toDomain() }
        )
        try ContentValidator.validate(catalog)
        cached = catalog
        return catalog
    }
}
