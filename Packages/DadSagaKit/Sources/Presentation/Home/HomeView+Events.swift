import SwiftUI

// MARK: - Links from outside the app

extension HomeView {
    /// Closes this screen's own sheets, then lets the presenter open the link (ADR-0023). It waits while something
    /// saves or an editor holds unsaved changes (ADR-0050): the task runs again once that ends, and the link opens then.
    func openPendingLink() async {
        guard let pendingLink, !viewModel.isCompleting, !unsavedWork.isHeld else { return }
        let hadSheet = settingsViewModel != nil || sagaFilm != nil
            || viewModel.worldMap != nil || photoViewer != nil
        settingsViewModel = nil
        sagaFilm = nil
        photoViewer = nil
        viewModel.closeMap()
        // A new sheet cannot appear while the old one is still sliding away.
        if hadSheet { try? await Task.sleep(for: .milliseconds(450)) }
        // A newer link replaced this one while the sheets closed; its own task opens it.
        guard !Task.isCancelled else { return }
        await viewModel.open(pendingLink)
        onLinkHandled()
    }
}

/// When the pending link may open: its task runs again when either changes.
struct LinkTurn: Equatable {
    let link: PendingLink?
    let mustWait: Bool
}

// MARK: - Coming back to the app

extension HomeView {
    /// Back in the app from the background, perhaps the next day: age, world and suggestions are read again. Not after
    /// Control Center or Face ID, which only make the app inactive, and not while a link waits: opening it reads home.
    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            wasInBackground = true
        case .active where wasInBackground:
            wasInBackground = false
            if pendingLink == nil { Task { await viewModel.appBecameActive() } }
        default:
            break
        }
    }
}

// MARK: - Celebrations

extension HomeView {
    /// A celebration's time on screen, kept here rather than in its badge, so drawing the badge again (one pane to
    /// two) doesn't restart it. VoiceOver reads it once, a moment in, when the card's sheet has finished closing and
    /// moving focus would no longer cut it off. Cancelled when a newer celebration replaces it: that one keeps its own.
    func celebrationTime() async {
        guard let celebration = viewModel.celebration else { return }
        do {
            try await Task.sleep(for: .milliseconds(600))
            AccessibilityNotification.Announcement(celebration.announcement).post()
            try await Task.sleep(for: .seconds(celebration.highlight >= .unlock ? 2.6 : 1.6))
        } catch {
            return
        }
        viewModel.celebrationFinished(id: celebration.id)
    }
}
