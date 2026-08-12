import SwiftUI

/// Displays one planet and its complete nested satellite output without inventing a single planet category.
struct GeneratedPlanetCard: View {
    let planet: GeneratedPlanet
    let ordinal: Int

    private let presentation = StarSystemPresentation()

    var body: some View {
        ExplorerCard(
            title: "Planet \(ordinal)",
            subtitle:
                "\(presentation.bodyID(planet.id)) · \(presentation.astronomicalUnits(planet.orbit.semiMajorAxis))",
            systemImage: "globe.americas.fill",
            tint: .orange
        ) {
            HStack(alignment: .center, spacing: 14) {
                PlanetaryBodySymbol(
                    physicalState: planet.physicalState,
                    liquidWaterCoverage: planet.environment.liquidWaterCoverage,
                    waterIceCoverage: planet.environment.waterIceCoverage,
                    diameter: 62
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.label(for: planet.physicalState.bulk))
                        .font(.title3.weight(.semibold))
                    Text("\(presentation.earthMasses(planet.mass)) · \(presentation.earthRadii(planet.radius))")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(planet.moons.count)")
                        .font(.title2.monospacedDigit().weight(.semibold))
                    Text(planet.moons.count == 1 ? "MOON" : "MOONS")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ClassificationTag(
                        label: presentation.label(for: planet.physicalState.bulk),
                        helpText: presentation.classificationHelp(for: planet.physicalState.bulk),
                        systemImage: "cube.fill",
                        tint: .orange
                    )
                    ClassificationTag(
                        label: presentation.label(for: planet.physicalState.visibleBoundary),
                        helpText: presentation.classificationHelp(for: planet.physicalState.visibleBoundary),
                        systemImage: "circle.lefthalf.striped.horizontal",
                        tint: .secondary
                    )
                    ClassificationTag(
                        label: presentation.label(for: planet.physicalState.atmosphere),
                        helpText: presentation.classificationHelp(for: planet.physicalState.atmosphere),
                        systemImage: "aqi.medium",
                        tint: .cyan
                    )
                    ClassificationTag(
                        label: presentation.label(for: planet.physicalState.thermal),
                        helpText: presentation.classificationHelp(for: planet.physicalState.thermal),
                        systemImage: "thermometer.medium",
                        tint: .red
                    )
                    ClassificationTag(
                        label: presentation.label(for: planet.physicalState.water),
                        helpText: presentation.classificationHelp(for: planet.physicalState.water),
                        systemImage: "drop.fill",
                        tint: .blue
                    )
                }
            }
            .scrollIndicators(.hidden)

            EagerAdaptiveGrid(minimumColumnWidth: 145, horizontalSpacing: 8, verticalSpacing: 8) {
                MetricTile(
                    "Mass", value: presentation.earthMasses(planet.mass), systemImage: "scalemass.fill", tint: .indigo)
                MetricTile(
                    "Radius", value: presentation.earthRadii(planet.radius),
                    detail: presentation.kilometers(planet.radius), systemImage: "circle.dashed", tint: .orange)
                MetricTile(
                    "Semi-major axis", value: presentation.astronomicalUnits(planet.orbit.semiMajorAxis),
                    systemImage: "arrow.trianglehead.2.clockwise.rotate.90", tint: .cyan)
                MetricTile(
                    "Eccentricity", value: presentation.number(planet.orbit.eccentricity.rawValue), systemImage: "oval",
                    tint: .teal)
                MetricTile(
                    "Inclination", value: "\(presentation.number(planet.orbit.inclinationDegrees))°",
                    systemImage: "angle", tint: .green)
                MetricTile(
                    "Progenitors", value: String(planet.progenitorCount),
                    systemImage: "point.3.filled.connected.trianglepath.dotted", tint: .purple)
            }

            CelestialCompositionView(title: "Present-day composition", composition: planet.composition)

            Text("ENVIRONMENT")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            PlanetaryEnvironmentGrid(environment: planet.environment)

            if !planet.moons.isEmpty {
                Divider()
                    .overlay(.white.opacity(0.12))
                HStack {
                    Label("Satellite system", systemImage: "moon.stars.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("Parent-relative orbits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    ForEach(Array(planet.moons.enumerated()), id: \.element.id) { index, moon in
                        GeneratedMoonCard(moon: moon, ordinal: index + 1)
                    }
                }
            }
        }
    }
}

#Preview("Seed 1 · Planet 1") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 1)
    )
    if let planet = system?.planets.first {
        ScrollView {
            GeneratedPlanetCard(planet: planet, ordinal: 1)
                .padding()
        }
        .frame(width: 720, height: 1_050)
        .background(Color(red: 0.025, green: 0.035, blue: 0.075))
        .preferredColorScheme(.dark)
    }
}
