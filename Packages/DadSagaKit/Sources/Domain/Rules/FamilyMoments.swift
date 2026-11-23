import Foundation

/// The firsts the family captured, from every entry, whoever recorded it. Pure and deterministic.
///
/// A first is what a child does (ADR-0065 §3.2, §3.3): captured once per child, by whichever parent was there. When both
/// parents captured it, the earlier capture is the child's moment; the other entry stays in the timeline.
public struct FamilyMoments: Hashable, Sendable {
    private let momentsByChild: [UUID: [CapturedMoment]]

    public init(events: [ProgressEvent], catalog: ContentCatalog) {
        var momentsByChild: [UUID: [CapturedMoment]] = [:]
        for entry in Timeline.familyEntries(from: events, catalog: catalog) {
            guard case .first(let first) = entry.kind else { continue }
            momentsByChild[entry.childID, default: []].append(
                CapturedMoment(
                    eventID: entry.id, authorID: entry.authorID, first: first, date: entry.date, note: entry.note,
                    photoIDs: entry.photoIDs
                )
            )
        }
        self.momentsByChild = momentsByChild
    }

    /// The firsts captured with the child, by anyone.
    public func capturedFirstIDs(for childID: UUID) -> Set<String> {
        Set((momentsByChild[childID] ?? []).map(\.first.id))
    }

    /// The child's legendary moments, newest first.
    public func moments(for childID: UUID) -> [CapturedMoment] {
        (momentsByChild[childID] ?? []).sorted { $0.date > $1.date }
    }
}
