import Application
import Domain

public enum ContentDataError: Error, Equatable {
    case missingResource(String)
    case unknownSkill(itemID: String, skill: String)
    case duplicateID(String)
    case unknownWorld(itemID: String, worldID: String)
    case emptyTip(itemID: String)
    case unknownLicence(itemID: String, licence: String)
    case emptyCredit(itemID: String)
    /// A look option whose part or id the app cannot draw.
    case unknownAppearanceOption(part: String, id: String)
    /// A look option the app can draw that the content does not name.
    case missingAppearanceOption(part: String, id: String)
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
            worlds: try dataSource.decode([WorldDTO].self, resource: "worlds").map { $0.toDomain() },
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
