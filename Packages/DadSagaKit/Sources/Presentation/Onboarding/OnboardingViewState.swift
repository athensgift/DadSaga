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
    public let partner: PartnerRowLabels
    public let continueTitle: String
    /// The way back to a saga exported from another iPhone (ADR-0057 §8).
    public let importTitle: String
    public let heroTitle: String
    public let finishTitle: String
    public let hero: HeroPickerContent
}
