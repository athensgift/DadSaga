import Application
import Observation

/// Decides what the app opens with: onboarding for a new player, home for a returning one.
@MainActor
@Observable
public final class RootViewModel {
    public enum State: Equatable, Sendable {
        case loading, onboarding, home
    }

    public private(set) var state: State = .loading

    /// Development builds only: whether the developer menu is offered.
    public var hasDeveloperMenu: Bool { resetProfile != nil }

    private let getProfile: any GetProfileUseCase
    private let resetProfile: (any ResetProfileUseCase)?

    /// - Parameter resetProfile: pass it only in development builds; it enables the developer menu.
    public init(getProfile: any GetProfileUseCase, resetProfile: (any ResetProfileUseCase)? = nil) {
        self.getProfile = getProfile
        self.resetProfile = resetProfile
    }

    public func onAppear() async {
        let profile = try? await getProfile.execute()
        state = profile == nil ? .onboarding : .home
    }

    public func onboardingFinished() {
        state = .home
    }

    /// Developer menu: wipe the profile and start again from onboarding.
    public func restartFromOnboarding() async {
        guard let resetProfile else { return }
        do {
            try await resetProfile.execute()
            state = .onboarding
        } catch {
            // Nothing was deleted, so stay where we are.
        }
    }
}
