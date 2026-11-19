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
//
// The app target is the composition root: the only place that knows every layer and wires them together.
let package = Package(
    name: "DadSagaKit",
    defaultLocalization: "el",
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
        // ViewModels (presenters) + SwiftUI views.
        .target(name: "Presentation", dependencies: ["Application", "Domain", "DesignSystem", "HeroArt", "Localization"]),
        // Tokens + reusable SwiftUI components. No business knowledge.
        .target(name: "DesignSystem"),
        // The code-drawn hero and children: bodies, outfits, gear, skin tones (ADR-0008, ADR-0028). Knows how the game's
        // heroes look, never what they do; drawn with DesignSystem's colours.
        .target(name: "HeroArt", dependencies: ["DesignSystem"]),
        // What the home-screen widget shows (ADR-0023). No SwiftUI and no WidgetKit, so `swift test` covers it.
        .target(name: "WidgetPresentation", dependencies: ["Application", "Domain", "Localization"]),
        // UI text in one String Catalog, shared by the app's and the widget's presenters (ADR-0027). No SwiftUI.
        .target(name: "Localization", dependencies: ["Domain"], resources: [.process("Resources")]),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Application", "Domain"], exclude: ["Fixtures"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Application", "Domain"]),
        .testTarget(name: "LocalizationTests", dependencies: ["Localization", "Domain"]),
        .testTarget(name: "WidgetPresentationTests", dependencies: ["WidgetPresentation", "Application", "Domain"]),
    ]
)
