/// Deletes the stored profile so the app starts again from onboarding. Used by the developer menu.
public protocol ResetProfileUseCase: Sendable {
    func execute() async throws
}

public struct DefaultResetProfileUseCase: ResetProfileUseCase {
    private let repository: any ProfileRepository

    public init(repository: any ProfileRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.deleteProfile()
    }
}
