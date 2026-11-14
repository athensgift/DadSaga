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
        let moments: MomentUseCases
        let getOutfit: (any GetOutfitUseCase)?

        public init(
            getProfile: any GetProfileUseCase,
            loadCatalog: any LoadContentCatalogUseCase,
            getAdventure: any GetAdventureUseCase,
            getProgress: any GetProgressUseCase,
            completeQuest: any CompleteQuestUseCase,
            defeatBoss: any DefeatBossUseCase,
            moments: MomentUseCases,
            getOutfit: (any GetOutfitUseCase)? = nil
        ) {
            self.getProfile = getProfile
            self.loadCatalog = loadCatalog
            self.getAdventure = getAdventure
            self.getProgress = getProgress
            self.completeQuest = completeQuest
            self.defeatBoss = defeatBoss
            self.moments = moments
            self.getOutfit = getOutfit
        }
    }

    /// Everything to do with legendary moments.
    public struct MomentUseCases: Sendable {
        let capture: any CaptureMomentUseCase
        let update: any UpdateMomentUseCase
        let delete: any DeleteMomentUseCase
        let getPhoto: any GetPhotoUseCase

        public init(
            capture: any CaptureMomentUseCase,
            update: any UpdateMomentUseCase,
            delete: any DeleteMomentUseCase,
            getPhoto: any GetPhotoUseCase
        ) {
            self.capture = capture
            self.update = update
            self.delete = delete
            self.getPhoto = getPhoto
        }
    }
}
