import Domain
import Foundation
import SwiftData

/// SwiftData storage shape of a progress event. Never leaves the Data layer.
@Model
final class ProgressEventRecord {
    var eventID: UUID
    /// "quest", "boss" or "first".
    var kind: String
    var contentID: String
    var date: Date

    init(event: ProgressEvent) {
        eventID = event.id
        date = event.date
        switch event.kind {
        case .quest(let id): (kind, contentID) = ("quest", id)
        case .boss(let id): (kind, contentID) = ("boss", id)
        case .first(let id): (kind, contentID) = ("first", id)
        }
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
        return ProgressEvent(id: eventID, kind: eventKind, date: date)
    }
}
