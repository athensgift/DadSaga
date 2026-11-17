import Foundation

/// What the home-screen widget draws, already in the user's language (ADR-0023). Plain values, so the WidgetKit
/// views stay dumb and every state is tested without SwiftUI.
public enum HomeWidgetContent: Hashable, Sendable {
    /// The weekly quest and, in the medium size, the latest moment.
    case tiles(Tiles)
    /// Before onboarding or when the data cannot be read: one line instead of the tiles.
    case message(String)

    public struct Tiles: Hashable, Sendable {
        /// Only when the family has more than one child.
        public let childName: String?
        public let quest: QuestTile
        public let moment: MomentTile
    }

    /// The weekly quest, or what stands in for it.
    public struct QuestTile: Hashable, Sendable {
        public let header: String
        public let title: String
        /// "+15 XP · Care"; `nil` when there is no quest.
        public let reward: String?
        /// "✓ Done this week" when the dad did it with this child this week. Otherwise `nil`: nothing is said.
        public let doneText: String?
        public let link: URL
    }

    /// The latest legendary moment, or a calm line when there is none yet.
    public struct MomentTile: Hashable, Sendable {
        public let header: String
        public let emoji: String
        public let title: String
        /// The day it happened; `nil` for the empty state.
        public let date: String?
        /// A small JPEG, only when the moment has a photo and the dad left photos on.
        public let photo: Data?
        public let link: URL
    }
}
