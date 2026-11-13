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
        let reset = DefaultResetProfileUseCase(profileRepository: store.profiles, progressRepository: store.progress)
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
                )
            )
        )
    }

    func makeContentExplorerViewModel() -> ContentExplorerViewModel {
        ContentExplorerViewModel(loadCatalog: loadContentCatalogUseCase)
    }
}
