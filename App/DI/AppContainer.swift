import Application
import Data
import Presentation

/// Composition root: the only place that knows concrete types from every layer and wires them together.
@MainActor
final class AppContainer {
    // MARK: Data
    private lazy var contentRepository: any ContentRepository = BundledContentRepository()
    /// Falls back to session-only storage if the on-disk store cannot be opened, so the app still starts.
    private lazy var store: LocalStore = (try? LocalStore.live()) ?? LocalStore.sessionOnly()

    /// Photos of legendary moments, kept on the device.
    private lazy var photoStore: any PhotoStore = FilePhotoStore.appDefault()

    // MARK: Use cases
    private var loadContentCatalogUseCase: any LoadContentCatalogUseCase {
        DefaultLoadContentCatalogUseCase(repository: contentRepository)
    }

    private var getProfileUseCase: any GetProfileUseCase {
        DefaultGetProfileUseCase(repository: store.profiles)
    }

    private var saveProfileUseCase: any SaveProfileUseCase {
        DefaultSaveProfileUseCase(contentRepository: contentRepository, profileRepository: store.profiles)
    }

    // MARK: Presentation
    func makeRootViewModel() -> RootViewModel {
        #if DEBUG
        let reset = DefaultResetProfileUseCase(
            profileRepository: store.profiles,
            progressRepository: store.progress,
            photoStore: photoStore
        )
        return RootViewModel(getProfile: getProfileUseCase, resetProfile: reset)
        #else
        return RootViewModel(getProfile: getProfileUseCase)
        #endif
    }

    func makeOnboardingViewModel(onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(loadCatalog: loadContentCatalogUseCase, saveProfile: saveProfileUseCase, onFinished: onFinished)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            useCases: HomeViewModel.UseCases(
                getProfile: getProfileUseCase,
                loadCatalog: loadContentCatalogUseCase,
                getAdventure: DefaultGetAdventureUseCase(repository: contentRepository),
                getProgress: DefaultGetProgressUseCase(contentRepository: contentRepository, progressRepository: store.progress),
                completeQuest: DefaultCompleteQuestUseCase(
                    contentRepository: contentRepository,
                    progressRepository: store.progress
                ),
                defeatBoss: DefaultDefeatBossUseCase(contentRepository: contentRepository, progressRepository: store.progress),
                moments: HomeViewModel.MomentUseCases(
                    capture: DefaultCaptureMomentUseCase(
                        contentRepository: contentRepository,
                        progressRepository: store.progress,
                        photoStore: photoStore
                    ),
                    update: DefaultUpdateMomentUseCase(progressRepository: store.progress, photoStore: photoStore),
                    delete: DefaultDeleteMomentUseCase(progressRepository: store.progress, photoStore: photoStore),
                    getPhoto: DefaultGetPhotoUseCase(photoStore: photoStore)
                )
            )
        )
    }

    func makeFamilyViewModel(onSaved: @escaping @MainActor () -> Void) -> FamilyViewModel {
        FamilyViewModel(getProfile: getProfileUseCase, saveProfile: saveProfileUseCase, onSaved: onSaved)
    }

    func makeContentExplorerViewModel() -> ContentExplorerViewModel {
        ContentExplorerViewModel(loadCatalog: loadContentCatalogUseCase)
    }
}
