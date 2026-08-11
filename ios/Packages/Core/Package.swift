// swift-tools-version: 6.2
import PackageDescription

// Domain models and shared contracts. Deliberately *not* MainActor-isolated
// by default: these value types cross actor boundaries (the networking actor
// decodes them, the UI renders them), so they stay nonisolated + Sendable.
let package = Package(
    name: "Core",
    defaultLocalization: "en",
    // macOS is declared purely so `swift test` can run the logic suites
    // natively, without a simulator round-trip. Core imports no UIKit.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "KafenoxCore", targets: ["KafenoxCore"])],
    targets: [
        .target(
            name: "KafenoxCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "KafenoxCoreTests", dependencies: ["KafenoxCore"]),
    ]
)
