import Domain
import Foundation

/// What the dad can play right now with one child, given the child's age today.
public struct Adventure: Hashable, Sendable {
    public let ageInMonths: Int
    /// The child is older than any world: nothing to play with them yet.
    public let isBeyondContent: Bool
    public let currentWorld: World?
    public let unlockedWorlds: [World]
    public let availableBosses: [BossFight]

    public init(
        ageInMonths: Int,
        currentWorld: World?,
        unlockedWorlds: [World],
        availableBosses: [BossFight],
        isBeyondContent: Bool = false
    ) {
        self.ageInMonths = ageInMonths
        self.isBeyondContent = isBeyondContent
        self.currentWorld = currentWorld
        self.unlockedWorlds = unlockedWorlds
        self.availableBosses = availableBosses
    }
}

public protocol GetAdventureUseCase: Sendable {
    /// `childCount` is the number of children in the family; sibling-only bosses need more than one.
    func execute(for child: Child, childCount: Int, on date: Date) async throws -> Adventure
}

public struct DefaultGetAdventureUseCase: GetAdventureUseCase {
    private let repository: any ContentRepository
    private let calendar: Calendar

    public init(repository: any ContentRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    public func execute(for child: Child, childCount: Int, on date: Date) async throws -> Adventure {
        let catalog = try await repository.fetchCatalog()
        let age = child.ageInMonths(at: date, calendar: calendar)
        if UnlockRules.isBeyondContent(catalog, ageInMonths: age) {
            return Adventure(
                ageInMonths: age,
                currentWorld: nil,
                unlockedWorlds: UnlockRules.unlockedWorlds(in: catalog, ageInMonths: age),
                availableBosses: [],
                isBeyondContent: true
            )
        }
        return Adventure(
            ageInMonths: age,
            currentWorld: UnlockRules.currentWorld(in: catalog, ageInMonths: age),
            unlockedWorlds: UnlockRules.unlockedWorlds(in: catalog, ageInMonths: age),
            availableBosses: UnlockRules.availableBosses(in: catalog, ageInMonths: age, childCount: childCount)
        )
    }
}
