// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Engine2AgentSessionAssembly",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(
            name: "Engine2AgentSessionAssembly",
            targets: ["Engine2AgentSessionAssembly"]
        )
    ],
    dependencies: [
        .package(path: "../AssemblySupport"),
        .package(path: "../Engine2"),
        .package(path: "../OfflineCaptureAssembly")
    ],
    targets: [
        .target(
            name: "Engine2AgentSessionAssembly",
            dependencies: [
                .product(
                    name: "Engine2AssemblySupport",
                    package: "AssemblySupport"
                ),
                .product(name: "Engine2", package: "Engine2"),
                .product(
                    name: "Engine2OfflineCaptureAssembly",
                    package: "OfflineCaptureAssembly"
                )
            ],
            path: "Sources/Engine2AgentSessionAssembly",
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
