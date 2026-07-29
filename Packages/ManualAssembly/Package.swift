// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Engine2ManualAssembly",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(
            name: "Engine2ManualAssembly",
            targets: ["Engine2ManualAssembly"]
        )
    ],
    dependencies: [
        .package(path: "../AssemblySupport"),
        .package(path: "../Engine2")
    ],
    targets: [
        .target(
            name: "Engine2ManualAssembly",
            dependencies: [
                .product(
                    name: "Engine2AssemblySupport",
                    package: "AssemblySupport"
                ),
                .product(name: "Engine2", package: "Engine2")
            ],
            path: "Sources/Engine2ManualAssembly",
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
