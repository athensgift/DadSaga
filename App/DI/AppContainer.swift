import Application
import Data
import Presentation

/// Composition root: the only place that knows concrete types from every layer and wires them together.
@MainActor
final class AppContainer {
    // MARK: Data
    private lazy var contentRepository: any ContentRepository = BundledContentRepository()
    private lazy var profileRepository: any ProfileRepository = Self.makeProfileRepository()

    /// Falls back to a session-only profile if the on-disk store cannot be opened, so the app still starts.
    private static func makeProfileRepository() -> any ProfileRepository {
        (try? SwiftDataProfileRepository.live()) ?? InMemoryProfileRepository()
    }

    // MARK: Use cases
    private var loadContentCatalogUseCase: any LoadContentCatalogUseCase {
        DefaultLoadContentCatalogUseCase(repository: contentRepository)
    }

    private var getProfileUseCase: any GetProfileUseCase {
        DefaultGetProfileUseCase(repository: profileRepository)
    }

    private var saveProfileUseCase: any SaveProfileUseCase {
        DefaultSaveProfileUseCase(contentRepository: contentRepository, profileRepository: profileRepository)
    }

    private var getAdventureUseCase: any GetAdventureUseCase {
        DefaultGetAdventureUseCase(repository: contentRepository)
    }

    // MARK: Presentation
    func makeRootViewModel() -> RootViewModel {
        #if DEBUG
        RootViewModel(getProfile: getProfileUseCase, resetProfile: DefaultResetProfileUseCase(repository: profileRepository))
        #else
        RootViewModel(getProfile: getProfileUseCase)
        #endif
    }

    func makeOnboardingViewModel(onFinished: @escaping @MainActor () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(loadCatalog: loadContentCatalogUseCase, saveProfile: saveProfileUseCase, onFinished: onFinished)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getProfile: getProfileUseCase, loadCatalog: loadContentCatalogUseCase, getAdventure: getAdventureUseCase)
    }

    func makeContentExplorerViewModel() -> ContentExplorerViewModel {
        ContentExplorerViewModel(loadCatalog: loadContentCatalogUseCase)
    }
}
