import AppIntents
import Foundation
import WidgetKit

/// The widget's settings: which child it shows, and whether the moment's photo appears (ADR-0023).
struct SelectChildIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget settings"
    static let description = IntentDescription("Choose the child this widget shows.")

    @Parameter(title: "Child")
    var child: ChildEntity?

    @Parameter(title: "Show photo", default: true)
    var showsPhoto: Bool

    init() {}
}

/// A child, as the widget's settings list them.
struct ChildEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Child"
    static let defaultQuery = ChildQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Reads the family from the shared store. Defaults to the first child, as home does.
struct ChildQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ChildEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ChildEntity] {
        try await WidgetContainer.children().map { ChildEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> ChildEntity? {
        try? await suggestedEntities().first
    }
}
