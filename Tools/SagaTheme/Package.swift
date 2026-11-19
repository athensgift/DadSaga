// swift-tools-version: 6.2
import PackageDescription

// Composes and renders the saga film's theme, an original piece made in code (ADR-0036 §8). The same score always
// renders the same WAV; each AAC encoding differs in its container's timestamps, so re-encode only after a change to
// the score. Run from the repository root:
//   swift run -c release --package-path Tools/SagaTheme SagaTheme /tmp/saga-theme.wav
//   afconvert -f m4af -d aac -b 128000 /tmp/saga-theme.wav Packages/DadSagaKit/Sources/SagaMusic/Resources/saga-theme.m4a
let package = Package(
    name: "SagaTheme",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "SagaTheme")
    ]
)
