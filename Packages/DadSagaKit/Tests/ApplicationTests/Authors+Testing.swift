import Application
import Domain
import Foundation

extension UUID {
    /// The one player of a test saga: until the co-op version every entry's author is the one profile (ADR-0065 §5).
    /// Fixed, since a stored profile keeps its id across saves.
    static let testDad = UUID(uuid: (0xD0, 0xD0, 0xD0, 0xD0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x01))
    /// The other parent in the family: their entries are the family's, never the test dad's (ADR-0065 §3).
    static let partner = UUID(uuid: (0x0A, 0x0A, 0x0A, 0x0A, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x02))
}

extension PlayerProfile {
    /// The test dad's profile. Tests about identity pass `id:` themselves.
    init(
        children: [Child],
        heroClassID: String,
        dadSkinTone: SkinTone = .mediumLight,
        dadAppearance: DadAppearance? = nil,
        hasPartner: Bool = true,
        removedChildren: [Child] = []
    ) {
        self.init(
            id: .testDad, children: children, heroClassID: heroClassID, dadSkinTone: dadSkinTone,
            dadAppearance: dadAppearance, hasPartner: hasPartner, removedChildren: removedChildren
        )
    }
}

extension ProgressEvent {
    /// An entry by the test dad. Tests about authors pass `authorID:` themselves.
    init(
        id: UUID = UUID(),
        kind: Kind,
        childID: UUID,
        date: Date,
        note: String? = nil,
        photoIDs: [String] = []
    ) {
        self.init(id: id, authorID: .testDad, kind: kind, childID: childID, date: date, note: note, photoIDs: photoIDs)
    }
}

/// The test dad, stored: the author of everything a recording use case records in a test.
struct TheDad: ProfileRepository {
    var profile = PlayerProfile(children: [Child(name: "Λένα", birthDay: nil)], heroClassID: "h1")

    func fetchProfile() async throws -> PlayerProfile? { profile }
    func create(_ profile: PlayerProfile) async throws {}
    func save(_ edit: FamilyEdit) async throws {}
    func save(_ edit: HeroEdit) async throws {}
    func bringBack(childID: UUID) async throws {}
    func deleteForGood(childID: UUID) async throws -> [String] { [] }
}

extension PlayerProfile {
    /// The test dad, for what is built for a player: his progress, his film's credits.
    static let testDad = PlayerProfile(children: [], heroClassID: "h1")
}

extension DadProgress {
    /// The test dad's progress: his own entries in `events`.
    init(events: [ProgressEvent], catalog: ContentCatalog) {
        self.init(of: .testDad, events: events, catalog: catalog)
    }
}
