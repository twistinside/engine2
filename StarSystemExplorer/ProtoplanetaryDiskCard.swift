import SwiftUI

/// Displays the immutable disk summary that records the planetary system's formation inputs.
struct ProtoplanetaryDiskCard: View {
    let disk: GeneratedProtoplanetaryDisk

    private let presentation = StarSystemPresentation()

    var body: some View {
        ExplorerCard(
            title: "Protoplanetary Disk",
            subtitle: "Resolved formation provenance",
            systemImage: "hurricane",
            tint: .teal
        ) {
            EagerAdaptiveGrid(minimumColumnWidth: 145, horizontalSpacing: 9, verticalSpacing: 9) {
                MetricTile(
                    "Initial gas", value: presentation.earthMasses(disk.initialGasMass), systemImage: "cloud.fill",
                    tint: .purple)
                MetricTile(
                    "Initial solids", value: presentation.earthMasses(disk.initialSolidMass),
                    systemImage: "circle.hexagonpath.fill", tint: .orange)
                MetricTile(
                    "Lifetime", value: "\(presentation.number(disk.lifetime.megayears)) Myr", systemImage: "hourglass",
                    tint: .indigo)
                MetricTile(
                    "Characteristic radius", value: presentation.astronomicalUnits(disk.characteristicRadius),
                    systemImage: "circle.dashed", tint: .teal)
                MetricTile(
                    "Inner edge", value: presentation.astronomicalUnits(disk.innerEdge),
                    systemImage: "arrow.down.right.and.arrow.up.left", tint: .cyan)
                MetricTile(
                    "Outer edge", value: presentation.astronomicalUnits(disk.outerEdge),
                    systemImage: "arrow.up.left.and.arrow.down.right", tint: .cyan)
                MetricTile(
                    "Water snow line", value: presentation.astronomicalUnits(disk.waterSnowLine),
                    systemImage: "snowflake", tint: .cyan)
                MetricTile(
                    "Density exponent", value: presentation.number(disk.surfaceDensityExponent),
                    systemImage: "function", tint: .green)
                MetricTile(
                    "Annuli", value: String(disk.annulusCount), systemImage: "circle.grid.3x3.fill", tint: .secondary)
            }

            CelestialCompositionView(
                title: "Initial solid composition",
                composition: disk.initialSolidComposition
            )
        }
    }
}
