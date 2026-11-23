import Application
import Domain
import Foundation
import Testing
@testable import Data

/// The film offers answered follow the parent (ADR-0065 §1): each answer is a record in their own zone, so a film is
/// offered once on whichever of their iPhones. The answers live in the defaults, so they are the one change sync
/// doesn't read from the store's history.
@Suite("Offers answered, in iCloud", .serialized)
struct OfferSyncTests: SyncBench {
    let root = FileManager.default.temporaryDirectory.appending(path: "dadsaga-offers-" + UUID().uuidString)
    let lena = Child(name: "Λένα", birthDay: .day(2025, 6, 2), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    @Test("Given iCloud on, when the dad answers an offer, then its record is in his own zone, the occasion's id escaped")
    func anAnswerBecomesARecord() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let occasion = "\(nikos.id.uuidString)/world/50%"

        await phone.offers.markAnswered(occasion)
        try await phone.send()

        let records = await cloud.records(in: .personal, of: "dad")
        #expect(records[.offer(occasionID: occasion)] == [:])
        #expect(records.keys.map(\.string).contains("offer-\(nikos.id.uuidString)%2Fworld%2F50%25"))
        #expect(await phone.offers.answeredOccasionIDs().contains(occasion))
    }

    @Test("Given an answer kept with no record (a kill in between), when the app resumes, then the record is sent")
    func anAnswerWithNoRecordIsSentAtResume() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let occasion = "\(nikos.id.uuidString)/birthday/1"
        // Only the defaults hold it: sync was never told.
        await phone.answers.markAnswered(occasion)

        let again = phone.relaunched()
        await again.coordinator.resume()
        try await again.send()

        #expect(try await again.cloudRecord(.offer(occasionID: occasion)) == [:])
        #expect(try await again.ledger().pending().isEmpty)
    }

    @Test("Given an offer answered on another iPhone, when its record comes, then it is answered here and never sent back")
    func anAnswerFromICloudIsAnsweredHere() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let occasion = "\(nikos.id.uuidString)/birthday/1"
        let name = RecordName.offer(occasionID: occasion)
        let sent = await cloud.requests.count

        await cloud.write(SyncRecord(name: name, zone: .personal), as: "dad")
        try await settle(phone)
        await phone.coordinator.resume()
        try await settle(phone)

        #expect(await phone.offers.answeredOccasionIDs().contains(occasion))
        #expect(await cloud.requests.count == sent)
        #expect(try await phone.ledger().pending().isEmpty)
    }

    @Test("Given answers about a child who becomes the family's, when the map is applied, then answers and records are renamed")
    func aChildMapRenamesTheAnswers() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let cloud = makeCloud()
        let (phone, _) = try await started(on: cloud)
        let familys = UUID()
        let world = "world/w2"
        await phone.offers.markAnswered(world)
        try await settle(phone)

        try await phone.coordinator.renameOffers(by: ChildMap(familyIDs: [lena.id: familys]))
        try await settle(phone)

        let renamed = "\(familys.uuidString)/birthday/1"
        #expect(await phone.offers.answeredOccasionIDs() == [renamed, world])
        let records = await cloud.records(in: .personal, of: "dad")
        #expect(Set(records.keys.filter { $0.type == .offer }) == [.offer(occasionID: renamed), .offer(occasionID: world)])
        #expect(try await phone.ledger().pending().isEmpty)
    }
}
