import Application
import Domain
import Foundation
import Localization
import Observation

/// Decides what the app opens with: onboarding for a new player, home for a returning one, and a calm stop when the
/// saved saga cannot be read (ADR-0026).
@MainActor
@Observable
public final class RootViewModel {
    public enum State: Equatable, Sendable {
        case loading, onboarding, home
        /// The store cannot be read. Nothing is changed; the dad can try again.
        case unavailable
    }

    public private(set) var state: State = .loading
    /// The tab on screen.
    public var selectedTab: RootTab = .adventure
    /// A link from outside the app waiting for home to open it.
    public private(set) var pendingLink: PendingLink?

    /// Development builds only: whether the developer menu is offered.
    public var hasDeveloperMenu: Bool { resetProfile != nil }

    /// Titles of the main tabs.
    public var tabs: RootTabs {
        RootTabs(
            adventure: strings.text("Adventure"),
            timeline: strings.text("Timeline")
        )
    }

    /// The screen shown while the saga cannot be read.
    public var unavailable: StoreUnavailableContent {
        StoreUnavailableContent(
            title: strings.text("We couldn't open your saga"),
            message: strings.text(
                """
                Everything you've recorded is still on this iPhone, and nothing was changed. Try again in a moment. \
                If it keeps happening, check that your iPhone has some free storage.
                """
            ),
            retryTitle: strings.text("Try again")
        )
    }

    private let getProfile: any GetProfileUseCase
    private let resetProfile: (any ResetProfileUseCase)?
    private let locale: Locale
    private var strings: Strings { Strings(locale: locale) }

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

    /// Only "no family" opens onboarding. A read error is not "no family": onboarding would give the children new ids
    /// and their history would drop out of sight.
    public func onAppear() async {
        do {
            let profile = try await getProfile.execute()
            state = profile == nil ? .onboarding : .home
            if state == .onboarding { pendingLink = nil }
        } catch {
            state = .unavailable
        }
    }

    /// From the can't-open screen: reads the saga again. A waiting link opens once home does.
    public func retry() async {
        guard state == .unavailable else { return }
        state = .loading
        await onAppear()
    }

    /// A URL the app was opened with (the widget). Anything that is not a DadSaga link, or any link before the family
    /// exists, is ignored.
    public func open(url: URL) {
        guard state != .onboarding, let link = AppLink(url: url) else { return }
        selectedTab = .adventure
        pendingLink = PendingLink(link)
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

/// A link from outside the app waiting to be opened. Views only pass it along and never look inside.
public struct PendingLink: Hashable, Sendable {
    let link: AppLink

    public init(_ link: AppLink) {
        self.link = link
    }
}

/// What the can't-open screen says.
public struct StoreUnavailableContent: Equatable, Sendable {
    public let title: String
    public let message: String
    public let retryTitle: String
}
