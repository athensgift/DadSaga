import SwiftData

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
}
