import Application
import Data
import Presentation

/// Composition root: the only place that knows concrete types from every layer and wires them together.
@MainActor
final class AppContainer {
    // MARK: Data
    private lazy var contentRepository: any ContentRepository = BundledContentRepository()

    // MARK: Use cases
    private var loadContentCatalogUseCase: any LoadContentCatalogUseCase {
        DefaultLoadContentCatalogUseCase(repository: contentRepository)
    }

    // MARK: Presentation
    func makeContentExplorerViewModel() -> ContentExplorerViewModel {
        ContentExplorerViewModel(loadCatalog: loadContentCatalogUseCase)
    }
}
