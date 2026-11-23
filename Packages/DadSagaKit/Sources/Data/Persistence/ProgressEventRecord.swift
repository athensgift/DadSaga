import Domain
import Foundation

extension ProgressEventRecord {
    convenience init(event: ProgressEvent) {
        let (kind, contentID): (String, String) = switch event.kind {
        case .quest(let id): ("quest", id)
        case .boss(let id): ("boss", id)
        case .first(let id): ("first", id)
        }
        self.init(
            eventID: event.id,
            authorID: event.authorID,
            kind: kind,
            contentID: contentID,
            childID: event.childID,
            date: event.date,
            note: event.note,
            photoIDs: event.photoIDs
        )
    }

    /// `nil` for a kind this version does not know, so newer data never crashes an older build.
    func toDomain() -> ProgressEvent? {
        let eventKind: ProgressEvent.Kind
        switch kind {
        case "quest": eventKind = .quest(id: contentID)
        case "boss": eventKind = .boss(id: contentID)
        case "first": eventKind = .first(id: contentID)
        default: return nil
        }
        return ProgressEvent(
            id: eventID, authorID: authorID, kind: eventKind, childID: childID, date: date, note: note, photoIDs: photoIDs
        )
    }
}
