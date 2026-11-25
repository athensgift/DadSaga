import Foundation

/// What VoiceOver reads of home's news: the celebration on screen, a new title's card, or both in one announcement, so
/// neither cuts the other off.
public struct SpokenNews: Equatable, Sendable {
    public let text: String
    let celebrationID: Int?
    let titleID: String?
}

extension HomeViewModel {
    /// The news VoiceOver hasn't read yet: each once, however often home comes back or reloads (ADR-0055 §6). `nil`
    /// while a sheet covers home, and while a new moment's sheet is still closing: its celebration is about to come.
    public var spokenNews: SpokenNews? {
        guard selectedQuest == nil, selectedBoss == nil, momentCapture == nil, pendingMomentCelebration == nil else { return nil }
        let newCelebration = celebration.flatMap { $0.id == spokenCelebrationID ? nil : $0 }
        let newCard = titleCard.flatMap { $0.titleID == spokenTitleID ? nil : $0 }
        let parts = [newCelebration?.announcement, newCard?.announcement].compactMap(\.self)
        guard !parts.isEmpty else { return nil }
        return SpokenNews(
            text: parts.joined(separator: ". "), celebrationID: newCelebration?.id, titleID: newCard?.titleID
        )
    }

    /// VoiceOver read it.
    public func spoke(_ news: SpokenNews) {
        if let id = news.celebrationID { spokenCelebrationID = id }
        if let id = news.titleID, titleCard?.titleID == id { spokenTitleID = id }
    }
}
