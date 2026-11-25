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
    public var selectedTab: RootTab = .adventure {
        didSet {
            if oldValue == .adventure, selectedTab != .adventure { onLeftAdventure?() }
        }
    }
    /// Runs each time the dad leaves Adventure for another tab, the map and Settings included: home's Undo ends then,
    /// as a Settings page can remove the child the card belongs to (ADR-0055 §3, ADR-0061 §2).
    @ObservationIgnored public var onLeftAdventure: (@MainActor () -> Void)?
    /// A link from outside the app, handed to home to open.
    public private(set) var pendingLink: PendingLink?
    /// A link that came while an editor holds changes the dad hasn't saved. It waits until nothing would be lost, and
    /// only then moves to Adventure and goes to home (ADR-0050). The holding editor is always on screen: home's and the
    /// timeline's are sheets over the tab bar, and "My family" hides it while it holds (ADR-0061 §2).
    private var waitingLink: PendingLink?
    /// Editors on any tab holding unsaved changes. The tabs see it through the environment.
    let unsavedWork = UnsavedWork()
    /// Changes each time an imported saga takes the place of the one on screen, so home and the timeline are built
    /// anew for it (ADR-0057 §7).
    public private(set) var sagaGeneration = 0
    /// Light/dark and haptics, applied to every screen (ADR-0030).
    public private(set) var preferences = PreferencesChoice()

    /// Titles of the main tabs.
    public var tabs: RootTabs {
        RootTabs(
            adventure: strings.text("Adventure"),
            map: strings.text("Map"),
            timeline: strings.text("Timeline"),
            settings: strings.text("Settings")
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
    private let getPreferences: any GetPreferencesUseCase
    private let locale: Locale
    private var strings: Strings { Strings(locale: locale) }

    public init(
        getProfile: any GetProfileUseCase,
        getPreferences: any GetPreferencesUseCase,
        locale: Locale = .current
    ) {
        self.getProfile = getProfile
        self.getPreferences = getPreferences
        self.locale = locale
        unsavedWork.onRelease = { [weak self] in self?.handOverWaitingLink() }
    }

    /// Only "no family" opens onboarding. A read error is not "no family": onboarding would give the children new ids
    /// and their history would drop out of sight.
    public func onAppear() async {
        preferences = PreferencesChoice(await getPreferences.execute())
        do {
            let profile = try await getProfile.execute()
            state = profile == nil ? .onboarding : .home
            if state == .onboarding { dropLinks() }
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

    /// A URL the app was opened with (the widget, a tapped notification). Anything that is not a DadSaga link, or any
    /// link before the family exists, is ignored; while the app is still loading the link waits for home. While an
    /// editor holds unsaved changes the link waits in front of it; the newest link is the one that waits.
    public func open(url: URL) {
        guard state != .onboarding, let link = AppLink(url: url) else { return }
        waitingLink = PendingLink(link)
        handOverWaitingLink()
    }

    private func handOverWaitingLink() {
        guard let waitingLink, !unsavedWork.isHeld else { return }
        self.waitingLink = nil
        selectedTab = .adventure
        pendingLink = waitingLink
    }

    private func dropLinks() {
        waitingLink = nil
        pendingLink = nil
    }

    /// Home opened this link. A newer one that arrived meanwhile stays, to open next.
    public func linkHandled(_ link: PendingLink) {
        if pendingLink == link { pendingLink = nil }
    }

    public func onboardingFinished() {
        selectedTab = .adventure
        state = .home
    }

    /// Settings stored new preferences.
    public func preferencesChanged(_ preferences: PreferencesChoice) {
        self.preferences = preferences
    }

    /// An imported saga is now the one on this iPhone, from Settings or from onboarding: home opens on it, and every tab
    /// is built anew, Settings back at its first page. A link waiting for the old saga is dropped.
    public func sagaImported() {
        dropLinks()
        // Settings is built anew with the old saga gone; nothing it held can be lost any more.
        unsavedWork.end(scope: UnsavedScope.settings)
        selectedTab = .adventure
        // From onboarding, home is built as it opens; only a home already on screen is built again.
        if state == .home { sagaGeneration += 1 }
        state = .home
    }

    /// A world was chosen on the map: home shows it, on Adventure.
    public func worldChosen() {
        selectedTab = .adventure
    }

    /// Settings erased the saga: onboarding opens, which takes the tabs away and closes home and its sheets. No hold
    /// of the old saga's editors is left to keep the new saga's links waiting.
    public func startedOver() {
        dropLinks()
        unsavedWork.endAll()
        selectedTab = .adventure
        state = .onboarding
    }
}

/// The four tabs, in their order (ADR-0061 §2).
public enum RootTab: Hashable, Sendable {
    case adventure, map, timeline, settings
}

public struct RootTabs: Equatable, Sendable {
    public let adventure: String
    public let map: String
    public let timeline: String
    public let settings: String
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
