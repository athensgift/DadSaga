/// What Settings needs from the root: telling it about new preferences, that the saga was erased, and that an
/// imported saga took its place.
public struct SettingsActions {
    let onPreferencesChanged: @MainActor (PreferencesChoice) -> Void
    let onStartedOver: @MainActor () -> Void
    let onSagaImported: @MainActor () -> Void

    public init(
        onPreferencesChanged: @escaping @MainActor (PreferencesChoice) -> Void,
        onStartedOver: @escaping @MainActor () -> Void,
        onSagaImported: @escaping @MainActor () -> Void
    ) {
        self.onPreferencesChanged = onPreferencesChanged
        self.onStartedOver = onStartedOver
        self.onSagaImported = onSagaImported
    }
}

/// Builds the pages pushed from Settings. Each page's presenter is built once, when its row is tapped.
public struct SettingsPages {
    public typealias MakeHero = @MainActor () -> HeroSettingsViewModel
    public typealias MakeFamily = @MainActor (_ onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel
    public typealias MakeReminder = @MainActor () -> ReminderSettingsViewModel
    public typealias MakeWardrobe = @MainActor () -> WardrobeViewModel
    public typealias MakeDataExport = @MainActor (_ onImported: @escaping @MainActor () -> Void) -> DataExportViewModel

    let makeHero: MakeHero
    let makeWardrobe: MakeWardrobe
    let makeFamily: MakeFamily
    let makeReminder: MakeReminder
    let makeDataExport: MakeDataExport
    /// Deletes the exported files once Settings closes: by then they were saved or sent (ADR-0057 §6).
    let discardExports: @MainActor () -> Void

    public init(
        makeHero: @escaping MakeHero,
        makeWardrobe: @escaping MakeWardrobe,
        makeFamily: @escaping MakeFamily,
        makeReminder: @escaping MakeReminder,
        makeDataExport: @escaping MakeDataExport,
        discardExports: @escaping @MainActor () -> Void
    ) {
        self.makeHero = makeHero
        self.makeWardrobe = makeWardrobe
        self.makeFamily = makeFamily
        self.makeReminder = makeReminder
        self.makeDataExport = makeDataExport
        self.discardExports = discardExports
    }
}
