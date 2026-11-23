import Domain

/// Keeps the title the player holds before entries go for good, so a deletion never lowers it (ADR-0055 §3): what
/// deleting an entry and deleting a child for good share. Asks only when it would raise the kept one; the store compares
/// again with what it keeps by then.
struct TitleKeeper {
    let contentRepository: any ContentRepository
    let standingRepository: any StandingRepository

    func keepHeldTitle(of player: PlayerProfile, events: [ProgressEvent]) async throws {
        let catalog = try await contentRepository.fetchCatalog()
        let standing = DadStanding(
            progress: DadProgress(of: player, events: events, catalog: catalog),
            catalog: catalog,
            kept: try await standingRepository.fetchKept()
        )
        if let title = standing.titleToKeep { try await standingRepository.keep(titleID: title.id, catalog: catalog) }
    }
}
