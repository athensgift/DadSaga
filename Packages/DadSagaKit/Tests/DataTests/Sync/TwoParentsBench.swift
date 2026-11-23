import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Two parents in one family on a fake iCloud (ADR-0065 §8): the dad, whose iCloud holds the family, and the partner,
/// who joined it with a saga of their own.
struct SyncedFamily {
    let cloud: FakeCloud
    /// The owner: account `dad`, the test dad's profile.
    let dad: SyncPhone
    /// The partner: account `mum`, the profile `UUID.partner`.
    let mum: SyncPhone
    /// The family's zone, in the dad's iCloud.
    let zone: SyncZone
    /// The dad's entry with Λένα, with a photo.
    let dadsEntry: ProgressEvent
    /// The partner's entry, recorded with their own Λένα before the join: the family's Λένα now.
    let mumsEntry: ProgressEvent
}

/// A parent with a saga of their own and iCloud on, before any join.
struct PartnerAlone {
    let phone: SyncPhone
    /// Their own Λένα: the same child as the family's, under another id.
    let ownLena: Child
    let entry: ProgressEvent
    /// The film offer they answered about their own Λένα.
    let occasion: String
}

extension SyncBench {
    /// The partner on their own: their hero, their own Λένα, an entry with her and a film offer answered about her;
    /// iCloud on, everything sent.
    func partnerAlone(
        _ name: String = "mum", on cloud: FakeCloud, content: any ContentRepository = FixedContent(catalog: .titlesAndAQuest)
    ) async throws -> PartnerAlone {
        let phone = phone(name, account: "mum", on: cloud, content: content)
        let ownLena = Child(name: "Λένα", birthDay: lena.birthDay, gender: .girl, skinTone: .light)
        try await phone.store.profiles.create(PlayerProfile(id: .partner, children: [ownLena], heroClassID: "h-chef"))
        let occasion = "\(ownLena.id.uuidString)/birthday/1"
        await phone.offers.markAnswered(occasion)
        let entry = ProgressEvent(
            id: UUID(), authorID: .partner, kind: .quest(id: "q1"), childID: ownLena.id,
            date: Date(timeIntervalSince1970: 1_800_000_500), note: "δικό της", photoIDs: []
        )
        try await phone.store.progress.add(entry)
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        return PartnerAlone(phone: phone, ownLena: ownLena, entry: entry, occasion: occasion)
    }

    /// The dad's saga shared with the partner, who joined with their own: one family on both iPhones, nothing
    /// waiting.
    func family(
        on cloud: FakeCloud, content: any ContentRepository = FixedContent(catalog: .titlesAndAQuest)
    ) async throws -> SyncedFamily {
        let dad = phone("dad", account: "dad", on: cloud, content: content)
        let dadsEntry = try await onboard(dad)
        #expect(try await dad.coordinator.turnOn() == .turnedOn)
        try await settle(dad)
        let partner = try await partnerAlone(on: cloud, content: content)
        let zone = try await dad.family()
        await cloud.share(zone, with: "mum")
        try await partner.phone.coordinator.join(zone, childMap: ChildMap(familyIDs: [partner.ownLena.id: lena.id]))
        try await settle(dad, partner.phone)
        let mumsEntry = ProgressEvent(
            id: partner.entry.id, authorID: .partner, kind: partner.entry.kind, childID: lena.id, date: partner.entry.date,
            note: partner.entry.note, photoIDs: partner.entry.photoIDs
        )
        return SyncedFamily(cloud: cloud, dad: dad, mum: partner.phone, zone: zone, dadsEntry: dadsEntry, mumsEntry: mumsEntry)
    }

    /// What `saga` says in the account's own zone.
    func saga(of account: String, on cloud: FakeCloud) async -> [String: SyncValue]? {
        await cloud.records(in: .personal, of: account)[.saga]
    }

    /// Another iPhone of the same parent, as an iCloud Backup of `phone` restored on it: the same saga, `Sync.store`
    /// and answers, and its own engines, which carry on from the state the copy holds. Nothing may be waiting or
    /// being written on `phone` while it is copied.
    func secondPhone(of phone: SyncPhone, named name: String) async throws -> SyncPhone {
        let folder = root.appending(path: name)
        try FileManager.default.copyItem(at: phone.folder, to: folder)
        let answers = MemoryOffers()
        for occasionID in await phone.answers.answeredOccasionIDs() { await answers.markAnswered(occasionID) }
        return SyncPhone(
            folder: folder, device: FakeSyncCloud(cloud: phone.cloud, account: phone.device.account), answers: answers,
            content: phone.content
        )
    }
}

extension SyncPhone {
    /// The family as this iPhone shows it, in order.
    func children() async throws -> [Child] {
        try #require(try await store.profiles.fetchProfile()).children
    }

    func removedChildren() async throws -> [Child] {
        try #require(try await store.profiles.fetchProfile()).removedChildren
    }

    func entryIDs() async throws -> Set<UUID> {
        Set(try await store.progress.fetchEvents().map(\.id))
    }

    /// Home, as this iPhone's parent sees it: their own progress and standing, and the family's moments.
    func home(on date: Date = Date(timeIntervalSince1970: 1_800_100_000)) async throws -> HomeOverview {
        try #require(try await DefaultGetHomeOverviewUseCase(
            contentRepository: content, profileRepository: store.profiles, progressRepository: store.progress,
            outfitRepository: store.outfit, standingRepository: store.standing, sagaOfferRepository: offers, timeZone: .gmt
        ).execute(childID: nil, worldID: nil, on: date))
    }

    func rename(_ child: Child, to name: String) async throws {
        var renamed = child
        renamed.name = name
        try await store.profiles.save(FamilyEdit(changed: [ChildEdit(child: renamed, fields: [.name])]))
    }

    /// A quest recorded by `author`, a minute after `minutes` of them.
    @discardableResult
    func record(_ child: Child, by author: UUID, minute: Int, photoIDs: [String] = []) async throws -> ProgressEvent {
        let entry = ProgressEvent(
            id: UUID(), authorID: author, kind: .quest(id: "q1"), childID: child.id,
            date: Date(timeIntervalSince1970: 1_800_001_000 + Double(minute) * 60), note: nil, photoIDs: photoIDs
        )
        try await store.progress.add(entry)
        return entry
    }
}

extension ContentCatalog {
    /// `titlesAndAQuest`, and the first `f1`, worth 30 XP.
    static let titlesAQuestAndAFirst = ContentCatalog(
        worlds: [], quests: ContentCatalog.titlesAndAQuest.quests, bosses: [],
        firsts: [
            FirstMoment(id: "f1", order: 1, emoji: "👣", title: LocalizedText(el: "x", en: "x"), xp: 30, companionTrait: nil)
        ],
        titles: ContentCatalog.threeTitles.titles
    )
}

extension Array {
    func asyncFilter(_ isIncluded: (Element) async -> Bool) async -> [Element] {
        var kept: [Element] = []
        for element in self where await isIncluded(element) { kept.append(element) }
        return kept
    }
}
