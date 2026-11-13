import Foundation
import SwiftData

/// SwiftData storage shape of the player profile. Never leaves the Data layer.
@Model
final class ProfileRecord {
    var childName: String
    var birthDate: Date
    var heroClassID: String

    init(childName: String, birthDate: Date, heroClassID: String) {
        self.childName = childName
        self.birthDate = birthDate
        self.heroClassID = heroClassID
    }
}
