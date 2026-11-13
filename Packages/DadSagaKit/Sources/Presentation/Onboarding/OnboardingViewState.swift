/// Display-ready state for onboarding. Plain values only.
public enum OnboardingViewState: Equatable, Sendable {
    case loading
    case loaded(OnboardingContent)
    case failed(message: String)
}

public struct OnboardingContent: Equatable, Sendable {
    public let welcomeTitle: String
    public let welcomeSubtitle: String
    public let namePlaceholder: String
    public let birthDateLabel: String
    public let continueTitle: String
    public let heroTitle: String
    public let heroSubtitle: String
    public let finishTitle: String
    public let backTitle: String
    public let heroes: [HeroOption]
}

public struct HeroOption: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let tagline: String
    public let look: HeroLook
}
