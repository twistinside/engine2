// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Engine2OfflineCaptureAssembly",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(
            name: "Engine2OfflineCaptureAssembly",
            targets: ["Engine2OfflineCaptureAssembly"]
        )
    ],
    dependencies: [
        .package(path: "../AssemblySupport"),
        .package(path: "../Engine2")
    ],
    targets: [
        .target(
            name: "Engine2OfflineCaptureAssembly",
            dependencies: [
                .product(
                    name: "Engine2AssemblySupport",
                    package: "AssemblySupport"
                ),
                .product(name: "Engine2", package: "Engine2")
            ],
            path: "Sources/Engine2OfflineCaptureAssembly",
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
