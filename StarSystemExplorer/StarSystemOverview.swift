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
                ZStack {
                    Circle()
                        .fill(.yellow.opacity(0.18))
                        .frame(width: 92, height: 92)
                        .blur(radius: 12)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .yellow, .orange],
                                center: .topLeading,
                                startRadius: 1,
                                endRadius: 42
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .yellow.opacity(0.8), radius: 18)
                }
                .accessibilityLabel("Host star")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
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
                        detail: "Aggregated, not given invented orbits",
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
            }
        }
    }
}
