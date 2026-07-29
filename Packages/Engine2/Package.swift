// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "Engine2",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        .library(name: "Engine2", targets: ["Engine2"]),
        .library(name: "Engine2GPUABI", targets: ["Engine2GPUABI"])
    ],
    targets: [
        .target(
            name: "Engine2GPUABI",
            path: "Sources/Engine2GPUABI",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Engine2",
            dependencies: [
                "Engine2GPUABI"
            ],
            path: "Sources/Engine2",
            resources: [
                .process("MetalShaders/HDRPresentationShaders.metal"),
                .process("MetalShaders/ModelShaders.metal")
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v6]
)
