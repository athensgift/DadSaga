import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for Settings (ADR-0030): language, appearance, haptics and the weekly reminder; the dad's hero and family;
/// contact, rating and sharing; what the app is; and starting over.
@MainActor
@Observable
public final class SettingsViewModel: Identifiable {
    public struct UseCases: Sendable {
        let savePreferences: any SavePreferencesUseCase
        let startOver: any StartOverUseCase

        public init(savePreferences: any SavePreferencesUseCase, startOver: any StartOverUseCase) {
            self.savePreferences = savePreferences
            self.startOver = startOver
        }
    }

    public let content: SettingsContent
    /// The root's preferences when Settings opened, then every change the dad makes here.
    public private(set) var preferences: PreferencesChoice
    public var isConfirmingStartOver = false
    public private(set) var isStartingOver = false
    public private(set) var errorMessage: String?
    public var mailFallback: MailFallback?

    private let useCases: UseCases
    private let appInfo: AppInfo
    private let actions: SettingsActions
    private let locale: Locale
    private let now: @Sendable () -> Date
    /// The last save asked for. Each save waits for the one before it, so the store ends with the newest choice.
    private var lastSave: Task<Void, Never>?
    private var strings: Strings { Strings(locale: locale) }

    public init(
        useCases: UseCases,
        preferences: PreferencesChoice,
        appInfo: AppInfo,
        actions: SettingsActions,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.useCases = useCases
        self.appInfo = appInfo
        self.actions = actions
        self.locale = locale
        self.now = now
        self.preferences = preferences
        content = SettingsContent.make(appInfo: appInfo, locale: locale)
    }

    /// Shown here and by the root at once, then stored.
    public func setAppearance(_ choice: AppearanceChoice) async {
        var changed = preferences
        changed.appearance = choice
        await save(changed)
    }

    public func setHapticsEnabled(_ isEnabled: Bool) async {
        var changed = preferences
        changed.isHapticsEnabled = isEnabled
        await save(changed)
    }

    public func askToStartOver() {
        errorMessage = nil
        isConfirmingStartOver = true
    }

    /// Erases the saga. On success the root opens onboarding, which closes this screen, so nothing runs after that.
    public func startOver() async {
        guard !isStartingOver else { return }
        isStartingOver = true
        do {
            try await useCases.startOver.execute(on: now())
            isStartingOver = false
            actions.onStartedOver()
        } catch {
            isStartingOver = false
            errorMessage = strings.text("Couldn't delete. Nothing was changed. Please try again.")
        }
    }

    /// An imported saga took the place of this one: the root rebuilds home and the timeline, which closes this screen.
    public func sagaImported() {
        actions.onSagaImported()
    }

    /// iOS reports whether Mail opened. If not, the dad gets the address to write to by hand.
    public func mailOpened(_ accepted: Bool) {
        guard !accepted, let contact = content.support?.contact else { return }
        mailFallback = MailFallback(
            title: strings.text("Mail couldn't open. Write to us at \(contact.address)"),
            address: contact.address,
            copyTitle: strings.text("Copy address"),
            closeTitle: strings.text("OK")
        )
    }

    private func save(_ changed: PreferencesChoice) async {
        guard changed != preferences else { return }
        preferences = changed
        actions.onPreferencesChanged(changed)
        let useCase = useCases.savePreferences
        let save = Task { [previous = lastSave] in
            await previous?.value
            await useCase.execute(changed.domain)
        }
        lastSave = save
        await save.value
    }
}
