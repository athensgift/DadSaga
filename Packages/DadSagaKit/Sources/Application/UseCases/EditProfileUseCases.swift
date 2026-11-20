import Domain
import Foundation

public enum ProfileEditError: Error, Equatable {
    /// There is nothing to edit before onboarding.
    case noProfile
}

/// Changes the dad's hero, skin tone and look. Progress and wardrobe are untouched: a class is only an identity and a
/// look (ADR-0008, ADR-0030, ADR-0044).
public protocol UpdateHeroUseCase: Sendable {
    func execute(heroClassID: String, skinTone: SkinTone, appearance: DadAppearance, on date: Date) async throws
}

/// Changes the children and keeps the dad's hero.
public protocol UpdateFamilyUseCase: Sendable {
    func execute(children: [Child], on date: Date) async throws
}

public struct DefaultUpdateHeroUseCase: UpdateHeroUseCase {
    private let editor: ProfileEditor

    public init(contentRepository: any ContentRepository, profileRepository: any ProfileRepository) {
        editor = ProfileEditor(contentRepository: contentRepository, profileRepository: profileRepository)
    }

    public func execute(heroClassID: String, skinTone: SkinTone, appearance: DadAppearance, on date: Date) async throws {
        try await editor.edit(on: date) { profile in
            profile.heroClassID = heroClassID
            profile.dadSkinTone = skinTone
            profile.dadAppearance = appearance
        }
    }
}

public struct DefaultUpdateFamilyUseCase: UpdateFamilyUseCase {
    private let editor: ProfileEditor

    public init(contentRepository: any ContentRepository, profileRepository: any ProfileRepository) {
        editor = ProfileEditor(contentRepository: contentRepository, profileRepository: profileRepository)
    }

    public func execute(children: [Child], on date: Date) async throws {
        try await editor.edit(on: date) { $0.children = children }
    }
}

/// Reads the stored profile, changes one part of it and stores it again through the same rules as onboarding.
private struct ProfileEditor: Sendable {
    let contentRepository: any ContentRepository
    let profileRepository: any ProfileRepository

    func edit(on date: Date, _ change: (inout PlayerProfile) -> Void) async throws {
        async let catalog = contentRepository.fetchCatalog()
        guard var profile = try await profileRepository.fetchProfile() else { throw ProfileEditError.noProfile }
        change(&profile)
        let valid = try ProfileRules.validated(profile, on: date, heroClasses: try await catalog.heroClasses)
        try await profileRepository.save(valid)
    }
}
