// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "BasicGameContent",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(name: "BasicGameContent", targets: ["BasicGameContent"])
    ],
    dependencies: [
        .package(path: "../AssemblySupport"),
        .package(path: "../Engine2")
    ],
    targets: [
        .target(
            name: "BasicGameContent",
            dependencies: [
                .product(name: "Engine2", package: "Engine2"),
                .product(
                    name: "Engine2AssemblySupport",
                    package: "AssemblySupport"
                )
            ],
            path: "Sources/BasicGameContent",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
