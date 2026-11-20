import Application
import Domain
import Foundation

/// Where a photo on screen comes from.
public enum PhotoSource: Equatable, Sendable {
    /// A photo stored on the device, by id.
    case stored(String)
    /// A photo just picked, not stored yet.
    case data(Data)
}

/// One photo in a sheet's photo field: already stored with the entry, or picked and waiting for Save.
public struct PhotoDraft: Equatable, Identifiable, Sendable {
    /// The stored id, or a new one for a picked photo, so the field and the viewer can tell photos apart.
    public let id: String
    public let source: PhotoSource

    public static func stored(_ id: String) -> PhotoDraft {
        PhotoDraft(id: id, source: .stored(id))
    }

    public static func picked(_ data: Data) -> PhotoDraft {
        PhotoDraft(id: "picked-" + UUID().uuidString, source: .data(data))
    }
}

/// The photos an entry will have once saved, as the dad arranges them: in his order, the first the cover, at most
/// `ProgressEvent.photoLimit` (ADR-0042 §3). Picked photos stay as they came until Save.
public struct PhotoDrafts: Equatable, Sendable {
    public static let limit = ProgressEvent.photoLimit

    public private(set) var items: [PhotoDraft]

    /// The photos an entry already has, in its order.
    public init(storedIDs: [String] = []) {
        items = storedIDs.prefix(Self.limit).map(PhotoDraft.stored)
    }

    /// How many more fit.
    public var remaining: Int { max(Self.limit - items.count, 0) }

    public var isFull: Bool { remaining == 0 }

    public var isEmpty: Bool { items.isEmpty }

    /// Adds picked photos after the others, as many as fit; the rest are left out.
    public mutating func append(_ photos: [Data]) {
        items += photos.prefix(remaining).map(PhotoDraft.picked)
    }

    public mutating func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    /// Moves the photo first; the others keep their order.
    public mutating func makeCover(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), index > 0 else { return }
        items.insert(items.remove(at: index), at: 0)
    }

    /// The whole list as the entry should keep it, for editing an entry.
    public var entryPhotos: [EntryPhoto] {
        items.map { photo in
            switch photo.source {
            case .stored(let id): .kept(id)
            case .data(let data): .added(data)
            }
        }
    }

    /// The picked photos alone, in order, for an entry being recorded.
    public var pickedPhotos: [Data] {
        items.compactMap { photo in
            if case .data(let data) = photo.source { data } else { nil }
        }
    }
}
