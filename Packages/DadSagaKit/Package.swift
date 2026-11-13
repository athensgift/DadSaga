// swift-tools-version: 6.2
import PackageDescription

// Clean Architecture: dependencies point inward only.
//
//   Presentation ─┐
//                 ├─▶ Application ─▶ Domain
//   Data ─────────┘
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
        .target(name: "Presentation", dependencies: ["Application", "Domain", "DesignSystem"]),
        // Tokens + reusable SwiftUI components. No business knowledge.
        .target(name: "DesignSystem"),

        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "ApplicationTests", dependencies: ["Application", "Domain"]),
        .testTarget(name: "DataTests", dependencies: ["Data", "Application", "Domain"]),
        .testTarget(name: "PresentationTests", dependencies: ["Presentation", "Application", "Domain"]),
    ]
)
