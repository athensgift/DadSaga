import SwiftUI

// MARK: - Links from outside the app

extension HomeView {
    /// Hands the pending link to home, which opens it once nothing would be lost (ADR-0023, ADR-0050). A newer link
    /// cancels this run: only a link that opened is reported handled.
    func openPendingLink() async {
        guard let pendingLink else { return }
        let opened = await viewModel.receive(pendingLink, unsavedWork: unsavedWork, closingOwnSheets: closeOwnSheets)
        if opened { onLinkHandled(pendingLink) }
    }

    /// The sheets this view owns: the film and the photo viewer. Home's own close as the link opens.
    private func closeOwnSheets() async {
        let hadSheet = sagaFilm != nil || photoViewer != nil
        sagaFilm = nil
        photoViewer = nil
        // A new sheet cannot appear while the old one is still sliding away.
        if hadSheet { try? await Task.sleep(for: .milliseconds(450)) }
    }
}

// MARK: - Coming back to the app

extension HomeView {
    /// Back in the app from the background, perhaps the next day: age, world and suggestions are read again. Not after
    /// Control Center or Face ID, which only make the app inactive. Also while a link waits: it checks the child after
    /// its own load, so the two can't mix.
    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            wasInBackground = true
        case .active where wasInBackground:
            wasInBackground = false
            Task { await viewModel.appBecameActive() }
        default:
            break
        }
    }
}

// MARK: - Celebrations

extension HomeView {
    /// VoiceOver reads the news once, a moment in, when the card's sheet has finished closing and moving focus would no
    /// longer cut it off. Cancelled when newer news replaces it: that one starts its own wait.
    func speakNews() async {
        guard let news = viewModel.spokenNews else { return }
        do {
            try await Task.sleep(for: .milliseconds(600))
        } catch {
            return
        }
        AccessibilityNotification.Announcement(news.text).post()
        viewModel.spoke(news)
    }

    /// A celebration's time on screen, kept here rather than in its badge, so drawing the badge again (one pane to
    /// two) doesn't restart it. Cancelled when a newer celebration replaces it: that one keeps its own.
    func celebrationTime() async {
        guard let celebration = viewModel.celebration else { return }
        do {
            try await Task.sleep(for: .seconds(celebration.highlight >= .moment ? 3.2 : 2.2))
        } catch {
            return
        }
        viewModel.celebrationFinished(id: celebration.id)
    }
}
