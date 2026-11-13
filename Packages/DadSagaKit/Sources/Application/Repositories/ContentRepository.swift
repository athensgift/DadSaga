import Domain

/// Port for reading game content. Implemented in the Data layer; use cases depend only on this protocol.
public protocol ContentRepository: Sendable {
    func fetchCatalog() async throws -> ContentCatalog
}
