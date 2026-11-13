import Domain
import Foundation

/// Validates the profile against the profile rules and the known hero classes, then stores it.
public protocol SaveProfileUseCase: Sendable {
    func execute(_ profile: PlayerProfile, on date: Date) async throws
}

public struct DefaultSaveProfileUseCase: SaveProfileUseCase {
    private let contentRepository: any ContentRepository
    private let profileRepository: any ProfileRepository

    public init(contentRepository: any ContentRepository, profileRepository: any ProfileRepository) {
        self.contentRepository = contentRepository
        self.profileRepository = profileRepository
    }

    public func execute(_ profile: PlayerProfile, on date: Date) async throws {
        let catalog = try await contentRepository.fetchCatalog()
        let valid = try ProfileRules.validated(profile, on: date, heroClasses: catalog.heroClasses)
        try await profileRepository.save(valid)
    }
}
