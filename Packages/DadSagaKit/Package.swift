// swift-tools-version: 6.2
import PackageDescription

// Clean Architecture: dependencies point inward only.
//
//   Presentation ───────┐
//   WidgetPresentation ─┼─▶ Application ─▶ Domain
//   Data ───────────────┘
//
//   Presentation, WidgetPresentation ─▶ Localization ─▶ Domain   (UI text, ADR-0027)
//   Presentation ─▶ HeroArt ─▶ DesignSystem                        (drawing, ADR-0028)
//   Presentation ─▶ FilmKit                                         (drawing the saga film, ADR-0037)
//   FilmKit                                                         (video writing, ADR-0036; knows no game)
//
// The app target is the composition root: the only place that knows every layer and wires them together.
let package = Package(
    name: "DadSagaKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Data", targets: ["Data"]),
        .library(name: "Presentation", targets: ["Presentation"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "HeroArt", targets: ["HeroArt"]),
        .library(name: "WidgetPresentation", targets: ["WidgetPresentation"]),
        .library(name: "Localization", targets: ["Localization"]),
        .library(name: "SagaMusic", targets: ["SagaMusic"]),
        .library(name: "FilmKit", targets: ["FilmKit"]),
    ],
    targets: [
        // Entities + enterprise business rules. Pure Swift, depends on nothing.
        .target(name: "Domain"),
        // Use cases + repository protocols (ports).
        .target(name: "Application", dependencies: ["Domain"]),
        // Repository implementations, DTOs, mappers, data sources (bundled JSON).
        .target(
            name: "Data",
            dependencies: ["Application", "Domain"],
            resources: [.process("Resources")]
        ),
        // ViewModels (presenters) + SwiftUI views. They also draw the saga film, through FilmKit (ADR-0037).
        .target(
            name: "Presentation",
            dependencies: ["Application", "Domain", "DesignSystem", "HeroArt", "Localization", "FilmKit"]
        ),
        // Tokens + reusable SwiftUI components. No business knowledge.
        .target(name: "DesignSystem"),
        // The code-drawn hero and children: bodies, outfits, gear, skin tones (ADR-0008, ADR-0028). Knows how the game's
        // heroes look, never what they do; drawn with DesignSystem's colours.
        .target(name: "HeroArt", dependencies: ["DesignSystem"]),
        // What the home-screen widget shows (ADR-0023). No SwiftUI and no WidgetKit, so `swift test` covers it.
        .target(name: "WidgetPresentation", dependencies: ["Application", "Domain", "Localization"]),
        // UI text in one String Catalog, shared by the app's and the widget's presenters (ADR-0027). No SwiftUI.
        .target(name: "Localization", dependencies: ["Domain"], resources: [.process("Resources")]),
        // The saga film's music and its credits, read by Data (ADR-0036 §8). Linked by the app only, never the widget.
        .target(name: "SagaMusic", resources: [.process("Resources")]),
        // Writes a film frame by frame from pictures, overlays and music (ADR-0036 §3). Apple frameworks only; it knows
        // nothing of the game, so its tests check frames, timing and sound, not content.
        .target(name: "FilmKit"),
        // Reads a written film back, for the tests of FilmKit and of the saga film's renderer. Not a test target, so
        // both can import it; no product, so the app never builds it.
        .target(name: "FilmTestSupport", path: "Tests/FilmTestSupport"),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Application", "Domain", "SagaMusic"], exclude: ["Fixtures"]),
        .testTarget(
            name: "PresentationTests",
            dependencies: ["Presentation", "HeroArt", "Application", "Domain", "FilmTestSupport"]
        ),
        .testTarget(name: "LocalizationTests", dependencies: ["Localization", "Domain"]),
        .testTarget(name: "FilmKitTests", dependencies: ["FilmKit", "FilmTestSupport", "SagaMusic"]),
        .testTarget(name: "WidgetPresentationTests", dependencies: ["WidgetPresentation", "Application", "Domain"]),
    ]
)
