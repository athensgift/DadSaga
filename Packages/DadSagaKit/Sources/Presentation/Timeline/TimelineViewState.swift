import Foundation

/// Display-ready state for the timeline. Plain values only.
public enum TimelineViewState: Equatable, Sendable {
    case loading
    case loaded(TimelineContent)
    case failed(LoadFailure)
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
    /// "Make a film", while the timeline shows at least one entry (ADR-0037 §6).
    public let filmTitle: String?
    /// For the rows' photos, full screen.
    public let viewer: PhotoViewerLabels
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
    public let symbol: String
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]
    /// How many photos, for VoiceOver, e.g. "3 φωτογραφίες"; `nil` without photos.
    public let photoCount: String?
}

/// The entry open for editing.
public enum TimelineEditor: Equatable, Identifiable, Sendable {
    /// A quest's or a boss's note and photos.
    case journal(JournalEditor)
    /// A first's own page, the same as home's step 2: its date, note and photos, and Delete (ADR-0042 §5).
    case moment(MomentDetails)

    public var id: UUID {
        switch self {
        case .journal(let editor): editor.id
        case .moment(let details): details.momentID
        }
    }
}

/// An entry's note and photos, open for editing.
public struct JournalEditor: Equatable, Identifiable, Sendable {
    /// The entry.
    public let id: UUID
    public let title: String
    public let note: String
    /// In the dad's order; the first is the cover.
    public let photoIDs: [String]
    public let labels: JournalLabels
    public let saveTitle: String
}
