import Foundation
import Testing

/// The language the system falls back to on a phone with neither Greek nor English is the one the app's own text falls
/// back to: English (ADR-0077). Read from what the plists are generated from: they are not in the repository, and CI
/// runs the package tests without generating them.
@Suite("Development region")
struct DevelopmentRegionTests {
    static func values(of pattern: String, in file: String) throws -> [String] {
        var url = URL(filePath: #filePath)
        for _ in 1...5 { url.deleteLastPathComponent() }
        let text = try String(contentsOf: url.appending(path: file), encoding: .utf8)
        let regex = try Regex(pattern, as: (Substring, Substring).self).anchorsMatchLineEndings()
        return text.matches(of: regex).map { String($0.output.1) }
    }

    @Test("Given the project, then the app's and the widget's Info.plist fall back to English, each naming it once")
    func plists() throws {
        // The key is indented under each target's `info.properties`. A third plist joins the list here.
        let regions = try Self.values(of: #"^ +CFBundleDevelopmentRegion: *([^\s#]+)"#, in: "project.yml")
        #expect(regions == ["en", "en"])
        let plists = try Self.values(of: #"^ +path: *(\S+\.plist)"#, in: "project.yml")
        #expect(plists == ["App/Info.plist", "Widget/Info.plist"])
    }

    @Test("Given the project and the package, then their own development language is English too")
    func projectAndPackage() throws {
        #expect(try Self.values(of: #"^ +developmentLanguage: *([^\s#]+)"#, in: "project.yml") == ["en"])
        let package = "Packages/DadSagaKit/Package.swift"
        #expect(try Self.values(of: #"defaultLocalization: "(\w+)""#, in: package) == ["en"])
    }
}
