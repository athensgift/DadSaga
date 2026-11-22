import Domain

/// Writes what the dad holds before his entries change, so a deletion never lowers his title or takes his gear
/// (ADR-0055 §3). Writes only when the title is higher than the kept one or the gear from before titles isn't kept yet.
/// If the write fails, the caller changes nothing.
struct StandingKeeper {
    let standingRepository: any StandingRepository

    func keepBeforeChange(_ progress: DadProgress, catalog: ContentCatalog) async throws {
        let kept = try await standingRepository.fetchKept()
        guard let next = DadStanding(progress: progress, catalog: catalog, kept: kept).toKeep else { return }
        try await standingRepository.keep(titleID: next.titleID, gearIDs: next.gearIDs ?? [])
    }
}
