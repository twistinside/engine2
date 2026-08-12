import SwiftUI

/// Displays one moon's formation provenance, stable orbit, composition, classifications, and environment.
struct GeneratedMoonCard: View {
    let moon: GeneratedMoon
    let ordinal: Int

    private let presentation = StarSystemPresentation()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PlanetaryBodySymbol(
                    physicalState: moon.physicalState,
                    liquidWaterCoverage: moon.environment.liquidWaterCoverage,
                    waterIceCoverage: moon.environment.waterIceCoverage,
                    diameter: 34
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Moon \(ordinal)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(presentation.bodyID(moon.id)) · \(presentation.label(for: moon.origin))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ClassificationTag(
                        label: presentation.label(for: moon.physicalState.bulk),
                        systemImage: "cube.fill",
                        tint: .orange
                    )
                    ClassificationTag(
                        label: presentation.label(for: moon.physicalState.visibleBoundary),
                        systemImage: "circle.lefthalf.striped.horizontal",
                        tint: .secondary
                    )
                    ClassificationTag(
                        label: presentation.label(for: moon.physicalState.atmosphere),
                        systemImage: "aqi.medium",
                        tint: .cyan
                    )
                    ClassificationTag(
                        label: presentation.label(for: moon.physicalState.thermal),
                        systemImage: "thermometer.medium",
                        tint: .red
                    )
                    ClassificationTag(
                        label: presentation.label(for: moon.physicalState.water),
                        systemImage: "drop.fill",
                        tint: .blue
                    )
                }
            }
            .scrollIndicators(.hidden)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                MetricTile(
                    "Mass", value: presentation.earthMasses(moon.mass), systemImage: "scalemass.fill", tint: .indigo)
                MetricTile(
                    "Radius", value: presentation.earthRadii(moon.radius), detail: presentation.kilometers(moon.radius),
                    systemImage: "circle.dashed", tint: .orange)
                MetricTile(
                    "Orbit", value: presentation.kilometers(moon.orbit.semiMajorAxis),
                    systemImage: "arrow.trianglehead.2.clockwise.rotate.90", tint: .cyan)
                MetricTile(
                    "Eccentricity", value: presentation.number(moon.orbit.eccentricity.rawValue), systemImage: "oval",
                    tint: .teal)
                MetricTile(
                    "Inclination", value: "\(presentation.number(moon.orbit.inclinationDegrees))°",
                    systemImage: "angle", tint: .green)
                MetricTile(
                    "Stable inner bound", value: presentation.kilometers(moon.minimumStableOrbit),
                    detail: "Roche limit", systemImage: "arrow.down.right.and.arrow.up.left", tint: .red)
                MetricTile(
                    "Stable outer bound", value: presentation.kilometers(moon.maximumStableOrbit),
                    detail: "Eccentric Hill limit", systemImage: "arrow.up.left.and.arrow.down.right", tint: .purple)
            }

            CelestialCompositionView(title: "Moon composition", composition: moon.composition)

            Text("ENVIRONMENT")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            PlanetaryEnvironmentGrid(environment: moon.environment)
        }
        .padding(14)
        .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.indigo.opacity(0.22), lineWidth: 1)
        }
    }
}

#Preview("Seed 30 · Planet 2 Moon") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 30)
    )
    if let planet = system?.planets.dropFirst().first,
        let moon = planet.moons.first
    {
        ScrollView {
            GeneratedMoonCard(moon: moon, ordinal: 1)
                .padding()
        }
        .frame(width: 760, height: 900)
        .background(Color(red: 0.025, green: 0.035, blue: 0.075))
        .preferredColorScheme(.dark)
    }
}
