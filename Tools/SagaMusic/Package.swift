// swift-tools-version: 6.2
import PackageDescription

// Composes and renders the saga film's music, original pieces made in code (ADR-0036 §8). The same score always renders
// the same WAV; each AAC encoding differs in its container's timestamps, so re-encode only a piece whose score changed.
// Run from the repository root, with an optional score id to render only that piece:
//   swift run -c release --package-path Tools/SagaMusic SagaMusic /tmp/saga-music [score id]
//   afconvert -f m4af -d aac -b 128000 /tmp/saga-music/<id>.wav Packages/DadSagaKit/Sources/SagaMusic/Resources/<id>.m4a
let package = Package(
    name: "SagaMusic",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "SagaMusic")
    ]
)
