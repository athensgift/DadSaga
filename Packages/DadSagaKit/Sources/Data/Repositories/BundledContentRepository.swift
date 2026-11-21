import Application
import Domain

public enum ContentDataError: Error, Equatable {
    case missingResource(String)
    case unknownSkill(itemID: String, skill: String)
    case duplicateID(String)
    case unknownWorld(itemID: String, worldID: String)
    case emptyTip(itemID: String)
    case unknownLicence(itemID: String, licence: String)
    case emptyText(itemID: String)
    /// A look option whose part or id the app cannot draw.
    case unknownAppearanceOption(part: String, id: String)
    /// A look option the app can draw that the content does not name.
    case missingAppearanceOption(part: String, id: String)
    /// An `onlyFor` word that is not an `Audience` (ADR-0051 §4).
    case unknownAudience(itemID: String, audience: String)
    /// A world neither before birth without ages, nor with a minimum age (ADR-0051 §7).
    case invalidWorldAges(worldID: String)
    /// A second world before birth, or one that isn't the first world by order.
    case misplacedBeforeBirthWorld(worldID: String)
    /// A card in the world before birth with a minimum age above 0 months.
    case agedBeforeBirth(itemID: String)
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
            appearanceOptions: try dataSource.decode([AppearanceOptionDTO].self, resource: "appearance")
                .map { try $0.toDomain() }
        )
        try ContentValidator.validate(catalog)
        cached = catalog
        return catalog
    }
}
