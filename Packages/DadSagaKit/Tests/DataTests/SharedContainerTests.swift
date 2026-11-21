import Foundation
import Testing
@testable import Data

/// Where the saga lives: the App Group folder, and never a silent stand-in in a release build (ADR-0048).
@Suite("Shared container")
struct SharedContainerTests {
    let group = URL(filePath: "/group", directoryHint: .isDirectory)
    let fallback = URL(filePath: "/private-support", directoryHint: .isDirectory)

    @Test("Given the App Group, when finding the saga's folder, then it is Application Support inside the group")
    func groupFolder() throws {
        let folder = try SharedContainer.directory(group: group, fallback: fallback)

        #expect(folder == group.appending(path: "Library/Application Support", directoryHint: .isDirectory))
    }

    @Test("Given no App Group and no fallback, when finding the saga's folder, then it throws appGroupUnavailable")
    func missingGroupThrowsInRelease() {
        #expect(throws: SharedContainerError.appGroupUnavailable) {
            try SharedContainer.directory(group: nil, fallback: nil)
        }
    }

    @Test("Given no App Group in a debug build, when finding the saga's folder, then it is the fallback")
    func missingGroupFallsBackInDebug() throws {
        #expect(try SharedContainer.directory(group: nil, fallback: fallback) == fallback)
    }
}
