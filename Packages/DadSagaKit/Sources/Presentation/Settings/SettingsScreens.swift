/// What Settings needs from the root: telling it about new preferences and that the saga was erased.
public struct SettingsActions {
    let onPreferencesChanged: @MainActor (PreferencesChoice) -> Void
    let onStartedOver: @MainActor () -> Void

    public init(
        onPreferencesChanged: @escaping @MainActor (PreferencesChoice) -> Void,
        onStartedOver: @escaping @MainActor () -> Void
    ) {
        self.onPreferencesChanged = onPreferencesChanged
        self.onStartedOver = onStartedOver
    }
}

/// Builds the pages pushed from Settings. Each page's presenter is built once, when its row is tapped.
public struct SettingsPages {
    public typealias MakeHero = @MainActor (_ onSaved: @escaping @MainActor () -> Void) -> HeroSettingsViewModel
    public typealias MakeFamily = @MainActor (_ onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel
    public typealias MakeReminder = @MainActor () -> ReminderSettingsViewModel

    let makeHero: MakeHero
    let makeFamily: MakeFamily
    let makeReminder: MakeReminder

    public init(makeHero: @escaping MakeHero, makeFamily: @escaping MakeFamily, makeReminder: @escaping MakeReminder) {
        self.makeHero = makeHero
        self.makeFamily = makeFamily
        self.makeReminder = makeReminder
    }
}

/// The Settings sheet and its pages, as home builds them.
public struct SettingsScreens {
    let makeSettings: @MainActor () -> SettingsViewModel
    let pages: SettingsPages

    public init(makeSettings: @escaping @MainActor () -> SettingsViewModel, pages: SettingsPages) {
        self.makeSettings = makeSettings
        self.pages = pages
    }
}
