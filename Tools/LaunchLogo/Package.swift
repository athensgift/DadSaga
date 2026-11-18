// swift-tools-version: 6.2
import PackageDescription

// Renders the launch screen image from the code-drawn avatars (ADR-0025). Run from the repository root:
//   swift run --package-path Tools/LaunchLogo -Xswiftc -enable-testing LaunchLogo
let package = Package(
    name: "LaunchLogo",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "../../Packages/DadSagaKit")],
    targets: [
        .executableTarget(name: "LaunchLogo", dependencies: [.product(name: "DesignSystem", package: "DadSagaKit")])
    ]
)
