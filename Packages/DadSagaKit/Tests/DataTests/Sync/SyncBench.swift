import Application
import CoreGraphics
import Domain
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Data

/// An iPhone that syncs: its saga store, photos and answers, the fake iCloud as it sees it, and the coordinator
/// (ADR-0065 §8). Nothing syncs by itself: a test sends and fetches, or settles.
struct SyncPhone {
    let folder: URL
    let store: LocalStore
    let photos: FilePhotoStore
    /// The offers answered, as the iPhone keeps them: they outlive a relaunch, as the defaults do.
    let answers: MemoryOffers
    /// The answers as the app writes them, each one also a record to send.
    let offers: SyncedSagaOfferRepository
    let device: FakeSyncCloud
    let coordinator: SyncCoordinator
    let content: any ContentRepository

    init(
        folder: URL, device: FakeSyncCloud, answers: MemoryOffers = MemoryOffers(),
        content: any ContentRepository = FixedContent(catalog: .titlesAndAQuest)
    ) {
        self.folder = folder
        self.device = device
        self.answers = answers
        self.content = content
        store = LocalStore.live(in: folder)
        photos = FilePhotoStore.moments(in: folder)
        coordinator = SyncCoordinator(
            saga: store.connection, syncStore: SyncStoreConnection(directory: { folder }), photos: photos,
            offers: answers, content: content, cloud: device
        )
        offers = SyncedSagaOfferRepository(answers, sync: coordinator)
    }

    var cloud: FakeCloud { device.cloud }
    var storeURL: URL { folder.appending(path: "DadSaga.store") }
    var syncStoreURL: URL { folder.appending(path: SyncStoreConnection.fileName) }

    /// The app killed and launched again over the same files: a new store connection, coordinator and engines.
    func relaunched() -> SyncPhone {
        device.forgetEngines()
        return SyncPhone(folder: folder, device: device, answers: answers, content: content)
    }

    /// `Sync.store`, once iCloud has been turned on.
    func ledger() async throws -> SyncLedger {
        try #require(try await coordinator.syncStore.open(creating: false))
    }

    /// The family's zone, as `Sync.store` names it.
    func family() async throws -> SyncZone {
        try #require(try await ledger().settings().familyZone)
    }

    func send() async throws {
        for engine in device.engines { try await engine.sendChanges() }
    }

    func fetch() async throws {
        for engine in device.engines { try await engine.fetchChanges() }
    }

    /// What the dad changed is read now and sent, without waiting for the store to wake sync.
    func sendChanges() async throws {
        await coordinator.drain()
        try await send()
    }

    /// The record this iPhone's account holds in iCloud; nil: none.
    func cloudRecord(_ name: RecordName) async throws -> [String: SyncValue]? {
        let account = try #require(device.account)
        let zone = name.type.scope == .personal ? SyncZone.personal : try await family()
        return await cloud.record(name, in: zone, of: account)?.fields
    }

    /// The names of every record the account's iCloud holds in the saga's two zones.
    func cloudNames() async throws -> Set<RecordName> {
        let account = try #require(device.account)
        let family = await cloud.records(in: try await family(), of: account)
        return Set(family.keys).union(await cloud.records(in: .personal, of: account).keys)
    }
}

/// A suite of iPhones on one fake iCloud.
protocol SyncBench {
    var root: URL { get }
    var lena: Child { get }
    var nikos: Child { get }
}

extension SyncBench {
    func makeCloud() -> FakeCloud {
        FakeCloud(downloads: root.appending(path: "downloads"))
    }

    func phone(
        _ name: String, account: String?, on cloud: FakeCloud,
        content: any ContentRepository = FixedContent(catalog: .titlesAndAQuest)
    ) -> SyncPhone {
        SyncPhone(
            folder: root.appending(path: name), device: FakeSyncCloud(cloud: cloud, account: account), content: content
        )
    }

    /// The dad's saga: Λένα and Νίκος, a wardrobe choice, an offer answered, and an entry with a photo, which is
    /// returned.
    @discardableResult
    func onboard(_ phone: SyncPhone) async throws -> ProgressEvent {
        try await phone.store.profiles.create(PlayerProfile(
            children: [lena, nikos], heroClassID: "h-cool",
            dadAppearance: DadAppearance(hair: .curly, hairColor: .black, beard: .none, glasses: .none)
        ))
        _ = try await phone.store.outfit.setChoice(.hidden, for: .care)
        await phone.offers.markAnswered("\(lena.id.uuidString)/birthday/1")
        let photoID = try await phone.photos.save(try smallImage())
        let entry = ProgressEvent(
            kind: .quest(id: "q1"), childID: lena.id, date: Date(timeIntervalSince1970: 1_800_000_000), note: "πρώτο",
            photoIDs: [photoID]
        )
        try await phone.store.progress.add(entry)
        return entry
    }

    /// An iPhone with the dad's saga and iCloud on, everything sent: nothing waits.
    func started(
        _ name: String = "iphone", account: String = "dad", on cloud: FakeCloud
    ) async throws -> (SyncPhone, ProgressEvent) {
        let phone = phone(name, account: account, on: cloud)
        let entry = try await onboard(phone)
        #expect(try await phone.coordinator.turnOn() == .turnedOn)
        try await settle(phone)
        return (phone, entry)
    }

    /// Each iPhone in turn reads what its dad changed, sends and fetches, until a whole round moves nothing.
    func settle(_ phones: SyncPhone...) async throws {
        for _ in 0..<10 {
            var moved = 0
            for phone in phones where phone.device.account != nil {
                await phone.coordinator.drain()
                for engine in phone.device.engines {
                    let before = await engine.moved
                    try await engine.sendChanges()
                    try await engine.fetchChanges()
                    moved += await engine.moved - before
                }
            }
            if moved == 0 { return }
        }
        Issue.record("Sync did not settle in ten rounds")
    }

    /// A record as another iPhone writes it: `fields` of `name`, in its zone of `phone`'s saga.
    func record(_ name: RecordName, _ fields: [String: SyncValue], for phone: SyncPhone) async throws -> SyncRecord {
        SyncRecord(name: name, zone: name.type.scope == .personal ? .personal : try await phone.family(), fields: fields)
    }

    func smallImage() throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: 24, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 24, height: 16))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}

/// Whether `condition` comes true within `seconds`: for what the store starts by itself, with no call to wait on.
func eventually(within seconds: Double = 5, _ condition: () async throws -> Bool) async rethrows -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
    while ContinuousClock.now < deadline {
        if try await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return try await condition()
}

/// Content that can't be read for a while: what applies a fetched batch needs the catalog.
actor UnreadableContent: ContentRepository {
    struct Unreadable: Error {}

    private var isReadable = true

    func setReadable(_ readable: Bool) {
        isReadable = readable
    }

    func fetchCatalog() async throws -> ContentCatalog {
        guard isReadable else { throw Unreadable() }
        return .titlesAndAQuest
    }
}
