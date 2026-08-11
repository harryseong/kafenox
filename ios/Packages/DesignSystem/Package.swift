// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DesignSystem",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [.library(name: "KafenoxDesignSystem", targets: ["KafenoxDesignSystem"])],
    dependencies: [.package(path: "../Core")],
    targets: [
        .target(
            name: "KafenoxDesignSystem",
            dependencies: [.product(name: "KafenoxCore", package: "Core")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
            ]
        )
    ]
)
