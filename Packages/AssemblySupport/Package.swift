// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Engine2AssemblySupport",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(
            name: "Engine2AssemblySupport",
            targets: ["Engine2AssemblySupport"]
        )
    ],
    dependencies: [
        .package(path: "../Engine2")
    ],
    targets: [
        .target(
            name: "Engine2AssemblySupport",
            dependencies: [
                .product(name: "Engine2", package: "Engine2")
            ],
            path: "Sources/Engine2AssemblySupport",
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
