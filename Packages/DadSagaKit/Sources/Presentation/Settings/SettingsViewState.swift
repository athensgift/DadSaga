import Foundation

public struct SettingsContent: Equatable, Sendable {
    public let title: String
    public let preferencesSection: String
    public let languageTitle: String
    /// The current language, named in itself: «Ελληνικά» or "English".
    public let languageValue: String
    public let languageFooter: String
    public let appearanceTitle: String
    public let appearanceOptions: [AppearanceOption]
    public let hapticsTitle: String
    public let reminderTitle: String
    public let heroSection: String
    public let heroTitle: String
    public let wardrobeTitle: String
    public let familyTitle: String
    /// Export and import of the saga (ADR-0057 §8).
    public let dataSection: String
    public let dataExportTitle: String
    /// `nil` when none of its rows can be offered yet.
    public let support: SupportSection?
    public let about: AboutSection
    public let startOver: StartOverLabels
}

public struct AppearanceOption: Equatable, Identifiable, Sendable {
    public let id: AppearanceChoice
    public let title: String
}

/// Contact, rate and share. Each row is `nil` until what it needs is configured.
public struct SupportSection: Equatable, Sendable {
    public let title: String
    public let contact: ContactRow?
    public let rate: LinkRow?
    public let share: ShareRow?
}

public struct ContactRow: Equatable, Sendable {
    public let title: String
    public let address: String
    /// A `mailto:` link with the subject and the app and iOS versions.
    public let mailURL: URL
}

public struct LinkRow: Equatable, Sendable {
    public let title: String
    public let url: URL
}

/// "Tell a friend": the App Store page and a short message.
public struct ShareRow: Equatable, Sendable {
    public let title: String
    public let url: URL
    /// The app's name, which is never translated.
    public let subject: String
    public let message: String
}

public struct AboutSection: Equatable, Sendable {
    public let title: String
    public let versionTitle: String
    public let versionValue: String
    /// What happens to the dad's data, in a sentence or two.
    public let privacyStatement: String
    public let privacyPolicy: LinkRow?
}

public struct StartOverLabels: Equatable, Sendable {
    public let row: String
    public let footer: String
    public let dialogTitle: String
    public let dialogMessage: String
    public let confirm: String
    public let cancel: String
}

/// Shown when Mail could not open: the address to write to by hand.
public struct MailFallback: Equatable, Identifiable, Sendable {
    public var id: String { address }
    public let title: String
    public let address: String
    public let copyTitle: String
    public let closeTitle: String
}
