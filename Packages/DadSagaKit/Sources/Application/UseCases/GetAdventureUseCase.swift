import Domain
import Foundation

/// What the dad can play right now, given the child's age today.
public struct Adventure: Hashable, Sendable {
    public let ageInMonths: Int
    public let currentWorld: World?
    public let unlockedWorlds: [World]
    public let availableQuests: [Quest]
    public let availableBosses: [BossFight]

    public init(
        ageInMonths: Int,
        currentWorld: World?,
        unlockedWorlds: [World],
        availableQuests: [Quest],
        availableBosses: [BossFight]
    ) {
        self.ageInMonths = ageInMonths
        self.currentWorld = currentWorld
        self.unlockedWorlds = unlockedWorlds
        self.availableQuests = availableQuests
        self.availableBosses = availableBosses
    }
}

public protocol GetAdventureUseCase: Sendable {
    func execute(for child: Child, on date: Date) async throws -> Adventure
}

public struct DefaultGetAdventureUseCase: GetAdventureUseCase {
    private let repository: any ContentRepository
    private let calendar: Calendar

    public init(repository: any ContentRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    public func execute(for child: Child, on date: Date) async throws -> Adventure {
        let catalog = try await repository.fetchCatalog()
        let age = child.ageInMonths(at: date, calendar: calendar)
        return Adventure(
            ageInMonths: age,
            currentWorld: UnlockRules.currentWorld(in: catalog, ageInMonths: age),
            unlockedWorlds: UnlockRules.unlockedWorlds(in: catalog, ageInMonths: age),
            availableQuests: UnlockRules.availableQuests(in: catalog, ageInMonths: age),
            availableBosses: UnlockRules.availableBosses(in: catalog, ageInMonths: age)
        )
    }
}
