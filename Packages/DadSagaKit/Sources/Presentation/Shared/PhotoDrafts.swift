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
    /// Photos picked and still being read from the library. They hold their room, keep Save waiting, and count as
    /// unsaved, so a Save or a close in the meantime never drops them.
    public private(set) var loadingCount = 0
    /// Photos the last pick couldn't read (still in iCloud, a format the app can't open), so the field can say so
    /// instead of leaving them out without a word. Cleared by the next change.
    public private(set) var unreadCount = 0

    /// The photos an entry already has, in its order.
    public init(storedIDs: [String] = []) {
        items = storedIDs.prefix(Self.limit).map(PhotoDraft.stored)
    }

    /// How many more fit.
    public var remaining: Int { max(Self.limit - items.count - loadingCount, 0) }

    public var isLoading: Bool { loadingCount > 0 }

    public var isFull: Bool { remaining == 0 }

    public var isEmpty: Bool { items.isEmpty }

    /// Adds picked photos after the others, as many as fit; the rest are left out.
    public mutating func append(_ photos: [Data]) {
        items += photos.prefix(remaining).map(PhotoDraft.picked)
        unreadCount = 0
    }

    /// `count` picked photos are being read; their room is kept for them.
    public mutating func startLoading(_ count: Int) {
        loadingCount += min(max(count, 0), remaining)
        unreadCount = 0
    }

    /// The photos being read have arrived: those that could be read, and how many couldn't. Given up with the field,
    /// it ends with none and nothing to report.
    public mutating func finishLoading(_ photos: [Data] = [], unread: Int = 0) {
        loadingCount = 0
        append(photos)
        unreadCount = max(unread, 0)
    }

    public mutating func remove(id: String) {
        items.removeAll { $0.id == id }
        unreadCount = 0
    }

    /// Moves the photo first; the others keep their order.
    public mutating func makeCover(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), index > 0 else { return }
        items.insert(items.remove(at: index), at: 0)
        unreadCount = 0
    }

    /// The whole list as the entry should keep it, for editing an entry.
    var entryPhotos: [EntryPhoto] {
        items.map { photo in
            switch photo.source {
            case .stored(let id): .kept(id)
            case .data(let data): .added(data)
            }
        }
    }

    /// The picked photos alone, in order, for an entry being recorded.
    var pickedPhotos: [Data] {
        items.compactMap { photo in
            if case .data(let data) = photo.source { data } else { nil }
        }
    }
}
