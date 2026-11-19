import HeroArt
import Presentation
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// The main screens (onboarding, home, the wardrobe, the timeline, settings) as images, so a change to how one looks
/// shows up in review (ADR-0034). Each is drawn in Greek and light mode, in English and dark mode, and in English at
/// the largest accessibility text size, which the accessibility audit does not check (ADR-0033).
///
/// A missing reference image is recorded and the test fails once; commit the new image under `__Snapshots__`.
/// After a deliberate change, delete the old images and run again.
/// One case at a time: every case draws in the app's one window.
@MainActor
@Suite("Screen snapshots", .serialized)
struct ScreenSnapshotTests {
    enum Look: String, CaseIterable {
        case greekLight = "el-light"
        case englishDark = "en-dark"
        case englishLargestText = "en-ax5"

        var locale: Locale { Locale(identifier: self == .greekLight ? "el_GR" : "en_US") }

        var traits: UITraitCollection {
            UITraitCollection { traits in
                traits.userInterfaceStyle = self == .englishDark ? .dark : .light
                traits.preferredContentSizeCategory = self == .englishLargestText
                    ? .accessibilityExtraExtraExtraLarge : .large
                traits.displayScale = 3
            }
        }
    }

    /// Dates and ages are drawn in UTC, on every Mac and in CI, like `SagaFixture.today`.
    init() {
        NSTimeZone.default = TimeZone(identifier: "UTC") ?? .gmt
    }

    @Test("Given a new dad, when onboarding opens, then it looks as recorded", arguments: Look.allCases)
    func onboarding(look: Look) async throws {
        let viewModel = SagaFixture(locale: look.locale).onboarding()
        await viewModel.onAppear()
        verify(OnboardingView(viewModel: viewModel), look: look, named: "onboarding")
    }

    @Test("Given a few weeks of play, when home opens, then it looks as recorded", arguments: Look.allCases)
    func home(look: Look) async throws {
        let saga = try await SagaFixture(locale: look.locale).played()
        let viewModel = saga.home()
        await viewModel.onAppear()
        let view = HomeView(
            viewModel: viewModel,
            makeWardrobe: { saga.wardrobe() },
            settings: saga.settingsScreens
        )
        verify(view, look: look, named: "home")
    }

    @Test("Given a few weeks of play, when the wardrobe opens, then it looks as recorded", arguments: Look.allCases)
    func wardrobe(look: Look) async throws {
        let viewModel = try await SagaFixture(locale: look.locale).played().wardrobe()
        await viewModel.onAppear()
        verify(WardrobeView(viewModel: viewModel, onClose: {}), look: look, named: "wardrobe")
    }

    @Test("Given a few weeks of play, when the timeline opens, then it looks as recorded", arguments: Look.allCases)
    func timeline(look: Look) async throws {
        let viewModel = try await SagaFixture(locale: look.locale).played().timeline()
        await viewModel.onAppear()
        verify(TimelineView(viewModel: viewModel), look: look, named: "timeline")
    }

    @Test("Given a few weeks of play, when settings open, then they look as recorded", arguments: Look.allCases)
    func settings(look: Look) async throws {
        let saga = try await SagaFixture(locale: look.locale).played()
        let view = SettingsView(viewModel: saga.settings(), pages: saga.settingsPages, onClose: {})
        verify(view, look: look, named: "settings")
    }

    /// A 390 × 844 pt screen drawn in the app's window, where Liquid Glass is drawn, and still: avatars at rest and no
    /// animations. Each test has loaded its view model first, so the screen is complete when it is drawn.
    private func verify(
        _ view: some View, look: Look, named name: String,
        fileID: StaticString = #fileID, file: StaticString = #filePath, line: UInt = #line, column: UInt = #column
    ) {
        let still = view
            .environment(\.locale, look.locale)
            .environment(\.avatarsAreStill, true)
            .transaction { $0.disablesAnimations = true }
        assertSnapshot(
            of: UIHostingController(rootView: still) as UIViewController,
            as: .savedScreen(traits: look.traits),
            named: look.rawValue,
            fileID: fileID, file: file, testName: name, line: line, column: column
        )
    }
}

extension Snapshotting where Value == UIViewController, Format == UIImage {
    /// The screen as it is saved: the new image goes through PNG before it is compared, like the reference it is
    /// compared with. Compared straight from memory, its other pixel format made the library count a difference of one
    /// level in 255 on a few hundred pixels as 1–15 % of pixels changed, most of all on CI's virtual GPU (ADR-0034).
    /// Through PNG, Liquid Glass's run-to-run noise is a few hundred pixels, far under the 0.1 % allowed, and one
    /// changed word is above it.
    static func savedScreen(traits: UITraitCollection) -> Snapshotting {
        let drawn = Snapshotting.image(
            drawHierarchyInKeyWindow: true, precision: 0.999, perceptualPrecision: 0.98,
            size: ViewImageConfig.iPhone13Pro.size, traits: traits
        )
        return Snapshotting(pathExtension: drawn.pathExtension, diffing: drawn.diffing) { controller in
            drawn.snapshot(controller).map { image in
                image.pngData().flatMap { UIImage(data: $0, scale: image.scale) } ?? image
            }
        }
    }
}
