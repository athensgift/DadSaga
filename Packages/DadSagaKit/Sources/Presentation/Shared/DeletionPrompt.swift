import Foundation
import Localization

/// The question asked before deleting something for good: an entry, or a child removed from the family.
public struct DeletionPrompt: Equatable, Identifiable, Sendable {
    /// What to delete: the entry, or the child.
    public let id: UUID
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String
}

extension DeletionPrompt {
    /// The question before an entry goes, the same wherever it is asked (ADR-0021 §4): what goes with it, for good, and
    /// what stays (ADR-0055 §3, §7).
    /// - Parameter isBoss: its badge goes with it.
    static func entry(id: UUID, hasPhotos: Bool, hasNote: Bool, isBoss: Bool = false, strings: Strings) -> DeletionPrompt {
        let journal: String? = switch (hasPhotos, hasNote) {
        case (true, true): strings.text("Your photos and note will be deleted with it, for good.")
        case (true, false): strings.text("Your photos will be deleted with it, for good.")
        case (false, true): strings.text("Your note will be deleted with it, for good.")
        case (false, false): nil
        }
        let stays = isBoss
            ? strings.text("Its badge will be removed. Your title and what you got stay.")
            : strings.text("Your title and what you got stay.")
        return DeletionPrompt(
            id: id,
            title: strings.text("Delete from the timeline?"),
            message: [journal, stays].compactMap(\.self).joined(separator: " "),
            confirmTitle: strings.text("Delete"),
            cancelTitle: strings.text("Cancel")
        )
    }
}
