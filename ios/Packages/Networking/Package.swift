// swift-tools-version: 6.2
import PackageDescription

// Transport only -- no feature knowledge. Nonisolated by default so the
// APIClient actor and its decoding stay off the main actor.
let package = Package(
    name: "Networking",
    defaultLocalization: "en",
    // macOS mirrors Core so `swift build` works without a simulator; the
    // client is URLSession + Keychain only, both cross-platform.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "KafenoxNetworking", targets: ["KafenoxNetworking"])],
    dependencies: [.package(path: "../Core")],
    targets: [
        .target(
            name: "KafenoxNetworking",
            dependencies: [.product(name: "KafenoxCore", package: "Core")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
