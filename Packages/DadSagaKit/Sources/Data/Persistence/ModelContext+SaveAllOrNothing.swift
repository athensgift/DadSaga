import SwiftData

/// The one author the change feed skips: sync's own writes, and the confirmed acts that replace rows (ADR-0065 §4).
enum StoreAuthor: String {
    case sync
}

extension ModelContext {
    /// Makes `changes` and saves them, or, if either throws, undoes every unsaved change before rethrowing. A failed
    /// save would otherwise stay pending in the context, be read back as if stored and be written by the next save,
    /// after the dad was told it failed (ADR-0048 §1). Saves only when something changed, so a write that changes
    /// nothing reaches neither the file nor its history (ADR-0065 §1; Apple's `save()` asks for this check).
    func saveAllOrNothing<T>(_ changes: () throws -> T) throws -> T {
        do {
            let result = try changes()
            if hasChanges { try save() }
            return result
        } catch {
            rollback()
            throw error
        }
    }

    /// As `saveAllOrNothing`, the save carrying `author` (ADR-0068 §2), put back after it in this turn. No change waits
    /// in the context between turns, so the save carries only this turn's changes.
    func saveAllOrNothing<T>(as author: StoreAuthor, _ changes: () throws -> T) throws -> T {
        let before = self.author
        self.author = author.rawValue
        defer { self.author = before }
        return try saveAllOrNothing(changes)
    }
}
