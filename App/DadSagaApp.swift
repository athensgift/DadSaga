import Presentation
import SwiftUI

@main
struct DadSagaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentExplorerView(viewModel: container.makeContentExplorerViewModel())
        }
    }
}
