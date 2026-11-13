import Domain

/// The stored player profile, or `nil` if onboarding has not happened yet.
public protocol GetProfileUseCase: Sendable {
    func execute() async throws -> PlayerProfile?
}

public struct DefaultGetProfileUseCase: GetProfileUseCase {
    private let repository: any ProfileRepository

    public init(repository: any ProfileRepository) {
        self.repository = repository
    }

    public func execute() async throws -> PlayerProfile? {
        try await repository.fetchProfile()
    }
}
