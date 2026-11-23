import Foundation
import Testing
@testable import Data

/// What sync writes in a log (ADR-0065 §7): nothing from a record, its id and its zone included.
@Suite("What sync logs of an error")
struct SyncLogTests {
    @Test("Given an error whose description names a record and an account, when sync logs it, then only its domain and code")
    func anErrorIsLoggedByDomainAndCode() {
        let childID = UUID().uuidString
        let fromICloud = NSError(domain: "CKErrorDomain", code: 26, userInfo: [
            NSLocalizedDescriptionKey: "Zone family-\(childID) of dad@example.com was not found",
            "RecordName": "child-\(childID)"
        ])

        #expect(fromICloud.syncLogLabel == "CKErrorDomain 26")
        #expect(SyncApplyError.historyTokenExpired.syncLogLabel == "Data.SyncApplyError 0")
        #expect(FamilyMoveError.unusableChildMap.syncLogLabel == "Data.FamilyMoveError 2")
    }
}
