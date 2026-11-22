import Domain

/// Writes what the dad holds before his entries change (ADR-0055 §3, §4). If the write fails, the caller changes
/// nothing.
struct StandingKeeper {
    let standingRepository: any StandingRepository

    /// Before an entry is recorded: the gear from before titles, the first time only. The title is not kept here, so
    /// an Undo of the entry takes back the title it brings by deleting it and nothing more.
    func keepBeforeRecording(_ progress: DadProgress, catalog: ContentCatalog) async throws {
        try await keep(\.toKeepBeforeRecording, progress, catalog)
    }

    /// Before an entry is deleted for good: also the title he holds, when it is higher than the kept one, so the
    /// deletion never lowers it or takes its gear.
    func keepBeforeDeleting(_ progress: DadProgress, catalog: ContentCatalog) async throws {
        try await keep(\.toKeepBeforeDeleting, progress, catalog)
    }

    private func keep(
        _ toKeep: KeyPath<DadStanding, KeptStanding?>, _ progress: DadProgress, _ catalog: ContentCatalog
    ) async throws {
        let kept = try await standingRepository.fetchKept()
        guard let next = DadStanding(progress: progress, catalog: catalog, kept: kept)[keyPath: toKeep] else { return }
        try await standingRepository.keep(titleID: next.titleID, gearIDs: next.gearIDs ?? [])
    }
}
