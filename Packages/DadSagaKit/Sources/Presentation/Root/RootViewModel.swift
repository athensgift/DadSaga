import Application
import Domain
import Foundation
import Observation

/// Decides what the app opens with: onboarding for a new player, home for a returning one.
@MainActor
@Observable
public final class RootViewModel {
    public enum State: Equatable, Sendable {
        case loading, onboarding, home
    }

    public private(set) var state: State = .loading
    /// The tab on screen.
    public var selectedTab: RootTab = .adventure
    /// A link from outside the app waiting for home to open it.
    public private(set) var pendingLink: AppLink?

    /// Development builds only: whether the developer menu is offered.
    public var hasDeveloperMenu: Bool { resetProfile != nil }

    /// Titles of the main tabs.
    public var tabs: RootTabs {
        RootTabs(
            adventure: LocalizedText(el: "Περιπέτεια", en: "Adventure").resolved(for: locale),
            timeline: LocalizedText(el: "Χρονολόγιο", en: "Timeline").resolved(for: locale)
        )
    }

    private let getProfile: any GetProfileUseCase
    private let resetProfile: (any ResetProfileUseCase)?
    private let locale: Locale

    /// - Parameter resetProfile: pass it only in development builds; it enables the developer menu.
    public init(
        getProfile: any GetProfileUseCase,
        resetProfile: (any ResetProfileUseCase)? = nil,
        locale: Locale = .current
    ) {
        self.getProfile = getProfile
        self.resetProfile = resetProfile
        self.locale = locale
    }

    public func onAppear() async {
        let profile = try? await getProfile.execute()
        state = profile == nil ? .onboarding : .home
        if state == .onboarding { pendingLink = nil }
    }

    /// A URL the app was opened with (the widget). Anything that is not a DadSaga link, or any link before the family
    /// exists, is ignored.
    public func open(url: URL) {
        guard state != .onboarding, let link = AppLink(url: url) else { return }
        selectedTab = .adventure
        pendingLink = link
    }

    public func linkHandled() {
        pendingLink = nil
    }

    public func onboardingFinished() {
        selectedTab = .adventure
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

public enum RootTab: Hashable, Sendable {
    case adventure, timeline
}

public struct RootTabs: Equatable, Sendable {
    public let adventure: String
    public let timeline: String
}
