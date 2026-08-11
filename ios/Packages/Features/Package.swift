// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Features",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [.library(name: "KafenoxFeatures", targets: ["KafenoxFeatures"])],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DesignSystem"),
        .package(path: "../Networking"),
    ],
    targets: [
        .target(
            name: "KafenoxFeatures",
            dependencies: [
                .product(name: "KafenoxCore", package: "Core"),
                .product(name: "KafenoxDesignSystem", package: "DesignSystem"),
                .product(name: "KafenoxNetworking", package: "Networking"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self),
            ]
        ),
        .testTarget(
            name: "KafenoxFeaturesTests",
            dependencies: ["KafenoxFeatures", .product(name: "KafenoxCore", package: "Core")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
