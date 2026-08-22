import SwiftUI

/// Presents stable gravity-system identity separately from metrics that change with the displayed snapshot.
struct GravitySystemDynamicsOverview: View {
    let model: GravitySystemExplorerModel
    let gravitySystem: GeneratedGravitySystem

    private let gravityPresentation = GravitySystemPresentation()
    private let starSystemPresentation = StarSystemPresentation()

    private var moonCount: Int {
        model.sourceSystem.planets.reduce(0) { $0 + $1.moons.count }
    }

    var body: some View {
        ExplorerCard(
            title: "Celestial Dynamics",
            subtitle: "Versioned planar gravity projection of one immutable generated system",
            systemImage: "point.3.connected.trianglepath.dotted",
            tint: .teal
        ) {
            EagerAdaptiveGrid(minimumColumnWidth: 190, horizontalSpacing: 10, verticalSpacing: 10) {
                MetricTile(
                    "Generation model",
                    value: starSystemPresentation.label(for: model.sourceSystem.modelVersion),
                    detail: "Seed \(model.sourceSystem.seed.rawValue)",
                    systemImage: "sparkles",
                    tint: .cyan
                )
                MetricTile(
                    "Dynamics model",
                    value: gravityPresentation.modelVersion(gravitySystem.modelVersion),
                    detail: "Deterministic planar rails",
                    systemImage: "gearshape.2.fill",
                    tint: .teal
                )
                MetricTile(
                    "Massive rails",
                    value: "\(gravitySystem.bodies.count)",
                    detail: "\(model.sourceSystem.planets.count) planets · \(moonCount) moons",
                    systemImage: "circle.hexagongrid.fill",
                    tint: .indigo
                )
                MetricTile(
                    "Motion plane",
                    value: "2D dynamics plane",
                    detail: "Top-down linear presentation",
                    systemImage: "square.grid.2x2",
                    tint: .mint
                )
            }

            GravitySystemLiveMetrics(model: model)
        }
    }
}
