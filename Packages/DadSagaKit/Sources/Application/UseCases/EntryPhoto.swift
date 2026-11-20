import Foundation

/// One photo of an entry as it should be once an edit is saved (ADR-0042): one already kept, by its id, or a new one.
/// An edit gives the whole list in the dad's order, so one shape covers adding several, removing one and choosing the
/// cover (the first).
public enum EntryPhoto: Equatable, Sendable {
    case kept(String)
    case added(Data)
}
