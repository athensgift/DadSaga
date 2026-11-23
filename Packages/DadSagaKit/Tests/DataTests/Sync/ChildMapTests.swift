import Foundation
import Testing
@testable import Data

/// Which of this iPhone's children is which of the family's (ADR-0065 §2, §4), as it travels in `saga`, and what it
/// does to the id of a film occasion.
@Suite("A child map")
struct ChildMapTests {
    let own = UUID(uuid: (0x0A, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x01))
    let familys = UUID(uuid: (0x0B, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 0x02))

    @Test("Given a map, when written, then one JSON object of UUID strings, and it reads back")
    func itTravelsAsOneObject() throws {
        let map = ChildMap(familyIDs: [own: familys])

        let data = try JSONEncoder().encode(map)

        #expect(String(bytes: data, encoding: .utf8) == """
        {"0A000000-0000-4000-8000-000000000001":"0B000000-0000-4000-8000-000000000002"}
        """)
        #expect(try JSONDecoder().decode(ChildMap.self, from: data) == map)
        #expect(try JSONDecoder().decode(ChildMap.self, from: Data("{}".utf8)) == ChildMap())
    }

    @Test("Given a map whose id is no UUID, when read, then it throws: never half a map")
    func aDamagedMapIsRefused() {
        let damaged = Data(#"{"0A000000-0000-4000-8000-000000000001":"the family's child"}"#.utf8)

        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ChildMap.self, from: damaged) }
    }

    @Test("Given an occasion of a mapped child, then its id starts with the family's child; any other id is as it was")
    func occasionsFollowTheirChild() {
        let map = ChildMap(familyIDs: [own: familys])
        let other = UUID()

        #expect(map.occasionID("\(own.uuidString)/birthday/1") == "\(familys.uuidString)/birthday/1")
        #expect(map.occasionID("\(own.uuidString)/world/w1") == "\(familys.uuidString)/world/w1")
        #expect(map.occasionID("\(own.uuidString.lowercased())/birthday/2") == "\(familys.uuidString)/birthday/2")
        #expect(map.occasionID("\(other.uuidString)/birthday/1") == "\(other.uuidString)/birthday/1")
        #expect(map.occasionID(own.uuidString) == own.uuidString)
        #expect(map.occasionID("first-year") == "first-year")
    }
}
