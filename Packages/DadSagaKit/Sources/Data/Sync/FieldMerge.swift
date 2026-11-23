import Domain
import Foundation

/// Which fields of a record that came reach the row (ADR-0065 §4). The one set of rules for a fetched record and for
/// the server's record of a save that met a newer one: both go through the applier. Pure.
enum FieldMerge {
    /// What to do with a save the server refused because its record had changed.
    enum Resolution: Hashable, Sendable {
        /// The change is forgotten: nothing is sent again.
        case drop
        /// The server's record is applied like a fetched one, then the waiting fields are sent again, set on it.
        case applyThenResend
    }

    /// Every field that came, but those whose local change waits (they go after it), and only values that differ from
    /// `stored`, the row's fields now; `stored` nil: there is no row yet.
    ///
    /// Time doesn't decide `heldTitleID`: it takes the higher of the two titles whatever waits and whatever the order
    /// of saves, since a kept title never goes down (`KeptStanding.keeping`: a stored title this version doesn't know
    /// is never replaced, one that comes is taken, nil never wins). A field this version doesn't map, or a value its
    /// column can't hold (a birth day that names no day, a number where a name goes), is left out: it stays on the
    /// server as it is.
    static func fieldsToSet(
        _ incoming: SyncRecord, stored: [String: SyncValue]?, waiting: Set<String>, catalog: ContentCatalog
    ) -> [String: SyncValue] {
        let type = incoming.name.type
        let kinds = SyncField.kinds(of: type)
        var fields: [String: SyncValue] = [:]
        for (field, value) in incoming.fields {
            guard let kind = kinds[field], kind.holds(value) else { continue }
            if type == .hero, field == SyncField.Hero.heldTitleID {
                fields[field] = heldTitle(arriving: value, stored: stored?[field], catalog: catalog)
            } else if !waiting.contains(field), stored?[field] != value {
                fields[field] = value
            }
        }
        return fields
    }

    /// `serverRecordChanged`: a save onto a child deleted for good is ignored, since `gone` is final, and the child
    /// goes here when the marker is applied. Anything else is applied and sent again; so is a local `gone` that met a
    /// record still there, which clears every other field.
    static func resolve(server: SyncRecord) -> Resolution {
        server.name.type == .child && server.fields[SyncField.Child.gone] == .bool(true) ? .drop : .applyThenResend
    }

    /// The title to keep in place of the stored one; nil when the stored one stays.
    private static func heldTitle(arriving: SyncValue, stored: SyncValue?, catalog: ContentCatalog) -> SyncValue? {
        guard case .string(let arriving) = arriving else { return nil }
        var kept = KeptStanding()
        if case .string(let stored)? = stored { kept.titleID = stored }
        let merged = kept.keeping(titleID: arriving, catalog: catalog).titleID
        return merged == kept.titleID ? nil : merged.map(SyncValue.string)
    }
}
