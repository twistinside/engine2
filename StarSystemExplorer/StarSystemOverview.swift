import SwiftUI

/// Summarizes identity and population before the detailed physical sections.
struct StarSystemOverview: View {
    let system: GeneratedStarSystem

    private let presentation = StarSystemPresentation()

    private var moonCount: Int {
        system.planets.reduce(0) { $0 + $1.moons.count }
    }

    private var retainedBodyMass: AstronomicalMass {
        AstronomicalMass(
            earthMasses: system.planets.reduce(0) { planetMass, planet in
                planetMass + planet.mass.earthMasses + planet.moons.reduce(0) { $0 + $1.mass.earthMasses }
            }
        )
    }

    var body: some View {
        ExplorerCard(
            title: "Generated System",
            subtitle: presentation.seed(system.seed),
            systemImage: "scope",
            tint: .cyan
        ) {
            HStack(alignment: .center, spacing: 22) {
                StellarBodySymbol(diameter: 64)
                    .accessibilityLabel("Host star")

                EagerAdaptiveGrid(minimumColumnWidth: 150, horizontalSpacing: 10, verticalSpacing: 10) {
                    MetricTile(
                        "Model",
                        value: presentation.label(for: system.modelVersion),
                        systemImage: "point.3.connected.trianglepath.dotted",
                        tint: .cyan
                    )
                    MetricTile(
                        "Planets",
                        value: String(system.planets.count),
                        detail: "Detailed survivors",
                        systemImage: "circle.grid.cross",
                        tint: .orange
                    )
                    MetricTile(
                        "Moons",
                        value: String(moonCount),
                        detail: "Resolved satellites",
                        systemImage: "moon.stars.fill",
                        tint: .indigo
                    )
                    MetricTile(
                        "Retained bodies",
                        value: presentation.earthMasses(retainedBodyMass),
                        systemImage: "scalemass.fill",
                        tint: .green
                    )
                    MetricTile(
                        "Residual bodies",
                        value: String(system.formationLedger.residualBodyCount),
                        detail: "No resolved orbits",
                        systemImage: "circle.dotted",
                        tint: .secondary
                    )
                    MetricTile(
                        "Disk extent",
                        value:
                            "\(presentation.astronomicalUnits(system.protoplanetaryDisk.innerEdge)) – \(presentation.astronomicalUnits(system.protoplanetaryDisk.outerEdge))",
                        systemImage: "ellipsis.curlybraces",
                        tint: .teal
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("Seed 10925987079005406032 · Overview") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 10_925_987_079_005_406_032)
    )
    if let system {
        StarSystemOverview(system: system)
            .padding()
            .frame(width: 1_600, height: 300)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}
