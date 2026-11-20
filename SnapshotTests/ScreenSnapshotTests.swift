import DesignSystem
import HeroArt
import Presentation
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// The main screens (onboarding, home with and without the film offer, the wardrobe, the timeline, settings and the
/// film sheet) as images, so a change to how one looks shows up in review (ADR-0034). Each is drawn in Greek and
/// light mode, in English and dark mode, and in English at the largest accessibility text size, which the
/// accessibility audit does not check (ADR-0033).
///
/// Run from the `DadSagaSnapshots` scheme, which fixes the region (en_US) and the time zone (UTC) on every Mac and in
/// CI. A missing reference image is recorded and the test fails once; commit the new image under `__Snapshots__`.
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
            makeSagaFilm: { saga.sagaFilm(request: $0) },
            settings: saga.settingsScreens
        )
        verify(view, look: look, named: "home")
    }

    @Test("Given a first birthday five days ago, when home opens, then it offers the film as recorded", arguments: Look.allCases)
    func homeFilmOffer(look: Look) async throws {
        let saga = try await SagaFixture(locale: look.locale).birthday()
        let viewModel = saga.home()
        await viewModel.onAppear()
        let view = HomeView(
            viewModel: viewModel,
            makeSagaFilm: { saga.sagaFilm(request: $0) },
            settings: saga.settingsScreens
        )
        verify(view, look: look, named: "home-film-offer")
    }

    @Test("Given a few weeks of play, when the wardrobe opens, then it looks as recorded", arguments: Look.allCases)
    func wardrobe(look: Look) async throws {
        let viewModel = try await SagaFixture(locale: look.locale).played().wardrobe()
        await viewModel.onAppear()
        verify(NavigationStack { WardrobeView(viewModel: viewModel) }, look: look, named: "wardrobe")
    }

    @Test("Given a few weeks of play, when the timeline opens, then it looks as recorded", arguments: Look.allCases)
    func timeline(look: Look) async throws {
        let saga = try await SagaFixture(locale: look.locale).played()
        let viewModel = saga.timeline()
        await viewModel.onAppear()
        let view = TimelineView(viewModel: viewModel, makeSagaFilm: { saga.sagaFilm(request: $0) })
        verify(view, look: look, named: "timeline")
    }

    @Test("Given two children and a birthday, when the film sheet opens, then it looks as recorded", arguments: Look.allCases)
    func filmSheet(look: Look) async throws {
        let viewModel = try await SagaFixture(locale: look.locale).birthday().sagaFilm()
        await viewModel.onAppear()
        verify(SagaFilmSheet(viewModel: viewModel, onClose: {}), look: look, named: "film-sheet")
    }

    /// The finished film is not drawn here: `VideoPlayer` is composited by Core Animation (ADR-0037 §7).
    @Test("Given a film 40 % made, when the film sheet shows it, then it looks as recorded", arguments: Look.allCases)
    func filmSheetMaking(look: Look) async throws {
        let viewModel = try await SagaFixture(locale: look.locale).birthday().sagaFilm(renderer: StalledFilmRenderer())
        await viewModel.onAppear()
        let making = Task { await viewModel.makeFilm(reduceMotion: false) }
        while !viewModel.isMaking(atLeast: 0.4) {
            try await Task.sleep(for: .milliseconds(10))
        }

        verify(SagaFilmSheet(viewModel: viewModel, onClose: {}), look: look, named: "film-sheet-making")

        viewModel.cancel()
        await making.value
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
        // The app's tint, as `RootView` sets it around every screen.
        let still = view
            .tint(DSColor.accent)
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

/// Reports 40 % and then waits until the film is cancelled, so the sheet can be drawn while a film is being made.
private struct StalledFilmRenderer: SagaFilmRendering {
    func render(_ script: SagaFilmScript, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> URL {
        await progress(0.4)
        try await Task.sleep(for: .seconds(600))
        throw CancellationError()
    }

    func discardFilms() async {}
}

private extension SagaFilmViewModel {
    func isMaking(atLeast progress: Double) -> Bool {
        if case .making(let making) = state { making.progress >= progress } else { false }
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
