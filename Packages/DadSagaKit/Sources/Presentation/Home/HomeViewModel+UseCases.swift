import Application

/// The use cases home depends on, bundled so the presenter takes one argument.
extension HomeViewModel {
    public struct UseCases: Sendable {
        let getProfile: any GetProfileUseCase
        let loadCatalog: any LoadContentCatalogUseCase
        let getAdventure: any GetAdventureUseCase
        let getProgress: any GetProgressUseCase
        let completeQuest: any CompleteQuestUseCase
        let defeatBoss: any DefeatBossUseCase
        /// Undo right after recording, and deleting a moment.
        let deleteEvent: any DeleteEventUseCase
        let moments: MomentUseCases
        let getOutfit: any GetOutfitUseCase
        /// The weekly reminder offer.
        let reminder: ReminderUseCases

        public init(
            getProfile: any GetProfileUseCase,
            loadCatalog: any LoadContentCatalogUseCase,
            getAdventure: any GetAdventureUseCase,
            getProgress: any GetProgressUseCase,
            completeQuest: any CompleteQuestUseCase,
            defeatBoss: any DefeatBossUseCase,
            deleteEvent: any DeleteEventUseCase,
            moments: MomentUseCases,
            getOutfit: any GetOutfitUseCase,
            reminder: ReminderUseCases
        ) {
            self.getProfile = getProfile
            self.loadCatalog = loadCatalog
            self.getAdventure = getAdventure
            self.getProgress = getProgress
            self.completeQuest = completeQuest
            self.defeatBoss = defeatBoss
            self.deleteEvent = deleteEvent
            self.moments = moments
            self.getOutfit = getOutfit
            self.reminder = reminder
        }
    }

    /// Everything to do with legendary moments.
    public struct MomentUseCases: Sendable {
        let capture: any CaptureMomentUseCase
        let update: any UpdateMomentUseCase
        let getPhoto: any GetPhotoUseCase

        public init(
            capture: any CaptureMomentUseCase,
            update: any UpdateMomentUseCase,
            getPhoto: any GetPhotoUseCase
        ) {
            self.capture = capture
            self.update = update
            self.getPhoto = getPhoto
        }
    }
}
