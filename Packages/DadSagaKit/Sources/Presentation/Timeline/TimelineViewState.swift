import Foundation

/// Display-ready state for the timeline. Plain values only.
public enum TimelineViewState: Equatable, Sendable {
    case loading
    case loaded(TimelineContent)
    case failed(message: String)
}

public struct TimelineContent: Equatable, Sendable {
    public let title: String
    /// "All" and one per child, when there are several children. Empty for one child.
    public let filters: [TimelineFilter]
    /// `nil` means every child.
    public let selectedFilter: UUID?
    /// One per month, newest first.
    public let sections: [TimelineSection]
    public let emptyTitle: String
    public let emptyMessage: String
}

public struct TimelineFilter: Equatable, Identifiable, Sendable {
    /// The child, or `nil` for everyone.
    public let id: UUID?
    public let title: String
}

public struct TimelineSection: Equatable, Identifiable, Sendable {
    /// e.g. "2026-11".
    public let id: String
    /// e.g. "Νοέμβριος 2026".
    public let title: String
    public let items: [TimelineItem]
}

public struct TimelineItem: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case quest, boss, moment
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    /// Child (when there are several), day, and the note or badge.
    public let subtitle: String
    public let badge: String
    public let symbol: String
    public let photoID: String?
}

/// The question asked before deleting an entry.
public struct DeletionPrompt: Equatable, Identifiable, Sendable {
    /// The entry to delete.
    public let id: UUID
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String
}

/// An entry's note and photo, open for editing.
public struct JournalEditor: Equatable, Identifiable, Sendable {
    /// The entry.
    public let id: UUID
    public let title: String
    public let note: String
    public let photoID: String?
    public let labels: JournalLabels
    public let saveTitle: String
}
