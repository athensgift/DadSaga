import Application
import Data
import Domain
import Foundation
import WidgetPresentation

/// The widget's composition root (ADR-0023). It reads what the app wrote and never writes: the store is opened
/// read-only, fresh for every request, so the widget never holds on to stale data or a store that does not exist yet.
enum WidgetContainer {
    private static let content: any ContentRepository = BundledContentRepository()

    static func highlights(childID: UUID?, on date: Date, withPhoto: Bool) async throws -> WeeklyHighlights? {
        let directory = SharedContainer.directory()
        let store = LocalStore.live(in: directory, readOnly: true)
        let useCase = DefaultGetWeeklyHighlightsUseCase(
            contentRepository: content,
            profileRepository: store.profiles,
            progressRepository: store.progress,
            photoStore: FilePhotoStore.moments(in: directory)
        )
        return try await useCase.execute(
            childID: childID,
            on: date,
            photoMaxPixelSize: withPhoto ? HomeWidgetPresenter.photoMaxPixelSize : nil
        )
    }

    /// The family, in the order the dad entered them, for the widget's "Child" setting.
    static func children() async throws -> [Child] {
        let store = LocalStore.live(in: SharedContainer.directory(), readOnly: true)
        return try await store.profiles.fetchProfile()?.children ?? []
    }
}
