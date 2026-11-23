import Foundation

/// The kinds of record the saga syncs as (ADR-0065 §1). The raw value is CloudKit's record type; it is never a Swift
/// case name read back.
public enum RecordType: String, Sendable, CaseIterable {
    // The family zone, sent in this order, so a partner's timeline fills before its pictures.
    case member = "Member", child = "Child", entry = "Entry", photo = "Photo"
    // The parent's Personal zone.
    case hero = "Hero", wardrobe = "Wardrobe", offer = "Offer", saga = "Saga"

    /// What a record's name starts with; `saga` is its whole name.
    var prefix: String {
        switch self {
        case .member: "member-"
        case .child: "child-"
        case .entry: "entry-"
        case .photo: "photo-"
        case .hero: "hero-"
        case .wardrobe: "wardrobe-"
        case .offer: "offer-"
        case .saga: "saga"
        }
    }

    /// Where its records live: the parent's own zone or the family's.
    var scope: SyncScope {
        switch self {
        case .member, .child, .entry, .photo: .family
        case .hero, .wardrobe, .offer, .saga: .personal
        }
    }
}

/// Which of the two kinds of zone a record is in (ADR-0065 §1): `Sync.store` files what waits under it, so a family
/// that moves to a new zone needs no rewrite.
enum SyncScope: String, Sendable {
    case personal, family
}

/// A record's name: its type and its stable id (ADR-0065 §1).
public struct RecordName: Hashable, Sendable {
    public let type: RecordType
    /// A UUID string, a skill, an escaped occasion id; empty for `saga`.
    public let id: String

    public init(_ type: RecordType, id: String) {
        self.type = type
        self.id = type == .saga ? "" : id
    }

    /// `nil` for a name of a type this version doesn't know: the record is ignored and left on the server.
    public init?(_ string: String) {
        guard let type = RecordType.allCases.first(where: { string.hasPrefix($0.prefix) }) else { return nil }
        let id = String(string.dropFirst(type.prefix.count))
        guard id.isEmpty == (type == .saga) else { return nil }
        self.init(type, id: id)
    }

    /// `child-<uuid>`, `offer-<escaped occasion id>`, `saga`.
    public var string: String { type.prefix + id }

    /// The id of a record named by one: a member, a child, an entry, a hero.
    public var uuid: UUID? { UUID(uuidString: id) }

    public static let saga = RecordName(.saga, id: "")
    public static func member(_ profileID: UUID) -> RecordName { RecordName(.member, id: profileID.uuidString) }
    public static func child(_ childID: UUID) -> RecordName { RecordName(.child, id: childID.uuidString) }
    public static func entry(_ eventID: UUID) -> RecordName { RecordName(.entry, id: eventID.uuidString) }
    public static func photo(_ photoID: String) -> RecordName { RecordName(.photo, id: photoID) }
    public static func hero(_ profileID: UUID) -> RecordName { RecordName(.hero, id: profileID.uuidString) }
    public static func wardrobe(skill: String) -> RecordName { RecordName(.wardrobe, id: skill) }

    /// An occasion id holds `/` (`<childID>/birthday/<n>`), which a record name escapes: `%` as `%25`, `/` as `%2F`.
    public static func offer(occasionID: String) -> RecordName {
        RecordName(.offer, id: occasionID.replacing("%", with: "%25").replacing("/", with: "%2F"))
    }

    /// The occasion an `offer-` record answers; `nil` for any other record, or an escape this version didn't write.
    public var occasionID: String? {
        guard type == .offer else { return nil }
        var result = ""
        var rest = id[...]
        while let first = rest.first {
            rest = rest.dropFirst()
            guard first == "%" else {
                result.append(first)
                continue
            }
            switch rest.prefix(2) {
            case "25": result.append("%")
            case "2F": result.append("/")
            default: return nil
            }
            rest = rest.dropFirst(2)
        }
        return result
    }
}

/// A zone the saga syncs into (ADR-0065 §1). A family zone's database is the private one when `owner` is this account,
/// the shared one otherwise; Personal is always private.
public enum SyncZone: Hashable, Sendable {
    case personal
    /// `owner`: the real user record name of the parent whose iCloud holds the family, never `__defaultOwner__`.
    case family(UUID, owner: String)
}

public enum SyncDatabase: String, Sendable {
    case `private`, shared
}

/// A field's value as it travels: the strings the store holds, so a value this version doesn't know passes through
/// untouched (ADR-0065 §1).
public enum SyncValue: Hashable, Sendable {
    case string(String), int(Int), bool(Bool), date(Date), strings([String])
    /// The field is absent: it sets nil.
    case cleared
}

/// One record, as much of it as a save or a fetch carries (ADR-0065 §4: a save sets only the fields that changed).
public struct SyncRecord: Hashable, Sendable {
    public var name: RecordName
    public var zone: SyncZone
    /// Only the fields this save or fetch carries.
    public var fields: [String: SyncValue]
    /// `Photo.image`: the stored JPEG to send, or the downloaded file.
    public var asset: URL?
    /// Opaque here: CloudKit's system fields for the record, kept in `Sync.store` between saves.
    public var systemFields: Data?
    /// Fetched: the real user record name of whoever created the record.
    public var creator: String?

    public init(
        name: RecordName,
        zone: SyncZone,
        fields: [String: SyncValue] = [:],
        asset: URL? = nil,
        systemFields: Data? = nil,
        creator: String? = nil
    ) {
        self.name = name
        self.zone = zone
        self.fields = fields
        self.asset = asset
        self.systemFields = systemFields
        self.creator = creator
    }
}

/// The zones a batch's records go to: Personal is fixed, the family's is the one `Sync.store` names.
struct SyncZones: Hashable, Sendable {
    let family: SyncZone

    func zone(for type: RecordType) -> SyncZone {
        type.scope == .personal ? .personal : family
    }
}
