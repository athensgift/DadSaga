/// Display-ready state for onboarding. Plain values only.
public enum OnboardingViewState: Equatable, Sendable {
    case loading
    case loaded(OnboardingContent)
    case failed(message: String)
}

public struct OnboardingContent: Equatable, Sendable {
    public let welcomeTitle: String
    public let welcomeSubtitle: String
    public let childEditor: ChildEditorLabels
    public let continueTitle: String
    public let heroTitle: String
    public let finishTitle: String
    public let hero: HeroPickerContent
}
