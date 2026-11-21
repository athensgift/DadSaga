import Domain
import Foundation
import SwiftData
import Testing
@testable import Data

/// Only three empty day columns mean "not born yet" (ADR-0053 §8). A row with some of them, or a day the calendar
/// doesn't have, is damaged: reading it fails, rather than quietly making a born child not born.
@Suite("Stored birth days", .serialized)
struct StoredBirthDayTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "dadsaga-birthday-" + UUID().uuidString)

    func storeChild(year: Int?, month: Int?, day: Int?) async throws -> UUID {
        let child = Child(name: "Άννα", birthDay: .day(2025, 3, 15))
        try await LocalStore.live(in: directory).profiles.save(PlayerProfile(children: [child], heroClassID: "h"))
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: DadSagaMigrationPlan.self,
            configurations: [
                ModelConfiguration(schema: schema, url: directory.appending(path: "DadSaga.store"), cloudKitDatabase: .none)
            ]
        )
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<ChildRecord>()) {
            record.birthYear = year
            record.birthMonth = month
            record.birthDay = day
        }
        try context.save()
        return child.id
    }

    @Test(
        "Given a stored child with only some day columns, or a day the calendar doesn't have, when reading, then it fails",
        arguments: [[2025, nil, nil], [nil, 3, 15], [2025, 3, nil], [2025, 2, 30]] as [[Int?]]
    )
    func damagedDayFails(columns: [Int?]) async throws {
        let id = try await storeChild(year: columns[0], month: columns[1], day: columns[2])

        await #expect(throws: StoredDataError.unreadableBirthDay(childID: id)) {
            try await LocalStore.live(in: directory).profiles.fetchProfile()
        }
    }

    @Test("Given a stored child with all three day columns empty, when reading, then the child is not born yet")
    func emptyDayIsNotBorn() async throws {
        _ = try await storeChild(year: nil, month: nil, day: nil)

        let profile = try #require(try await LocalStore.live(in: directory).profiles.fetchProfile())
        #expect(profile.children.first?.isBorn == false)
    }
}
