import Foundation
import SwiftUI

/// Places resolved planets on a selectable linear or logarithmic axis while keeping body symbols legible.
struct StarSystemOrbitDiagram: View {
    let system: GeneratedStarSystem

    @State private var scale: StarSystemOrbitScale

    private let presentation = StarSystemPresentation()
    private let orbitRange: StarSystemOrbitRange
    private let leadingTrackInset = 58.0
    private let trailingTrackInset = 78.0
    private let moonDiameter = 10.0
    private let moonSpacing = 2.0

    private var orbitalRange: ClosedRange<Double> {
        orbitRange.visibleRange
    }

    private var snowLineAstronomicalUnits: Double {
        system.protoplanetaryDisk.waterSnowLine.astronomicalUnits
    }

    private var showsSnowLine: Bool {
        orbitalRange.contains(snowLineAstronomicalUnits)
    }

    private var subtitle: String {
        let scaleDescription = scale == .logarithmic ? "Zero-safe logarithmic" : scale.title
        let domain = orbitRange.usesFallback ? "0 AU to disk outer edge" : "0 AU to outer orbit + 10%"
        return "\(scaleDescription) orbit scale · \(domain) · body sizes are symbolic"
    }

    private var rangeLegend: String {
        orbitRange.usesFallback ? "Disk outer edge" : "Outer orbit + 10%"
    }

    private var resolvedMoonCount: Int {
        system.planets.reduce(0) { count, planet in
            count + planet.moons.count
        }
    }

    private var orbitScalePicker: some View {
        Picker("Orbit scale", selection: $scale) {
            ForEach(StarSystemOrbitScale.allCases) { option in
                Text(option.title)
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 300)
        .help("Switch between linear and zero-safe logarithmic orbital distance")
    }

    var body: some View {
        ExplorerCard(
            title: "Orbital Architecture",
            subtitle: subtitle,
            systemImage: "circle.hexagongrid.fill",
            tint: .indigo,
            accessory: {
                orbitScalePicker
            }
        ) {
            GeometryReader { proxy in
                ZStack {
                    Canvas { context, size in
                        let midY = size.height * 0.47
                        let trackStart = leadingTrackInset
                        let trackEnd = size.width - trailingTrackInset
                        let diskRect = CGRect(
                            x: trackStart,
                            y: midY - 12,
                            width: max(1, trackEnd - trackStart),
                            height: 24
                        )
                        context.fill(
                            Path(roundedRect: diskRect, cornerRadius: 12),
                            with: .linearGradient(
                                Gradient(colors: [.cyan.opacity(0.08), .purple.opacity(0.18), .cyan.opacity(0.05)]),
                                startPoint: CGPoint(x: trackStart, y: midY),
                                endPoint: CGPoint(x: trackEnd, y: midY)
                            )
                        )

                        var axis = Path()
                        axis.move(to: CGPoint(x: trackStart, y: midY))
                        axis.addLine(to: CGPoint(x: trackEnd, y: midY))
                        context.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)

                        if showsSnowLine {
                            let snowLineX = orbitPosition(for: snowLineAstronomicalUnits, width: size.width)
                            var snowLine = Path()
                            snowLine.move(to: CGPoint(x: snowLineX, y: 22))
                            snowLine.addLine(to: CGPoint(x: snowLineX, y: size.height - 45))
                            context.stroke(
                                snowLine,
                                with: .color(.cyan.opacity(0.65)),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                            context.draw(
                                Text("snow line")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.cyan),
                                at: CGPoint(x: snowLineX + 4, y: 18),
                                anchor: .bottomLeading
                            )
                        }

                        for (index, planet) in system.planets.enumerated() {
                            let lane = planetLaneY(index: index, height: size.height)
                            let periapsis =
                                planet.orbit.semiMajorAxis.astronomicalUnits
                                * (1 - planet.orbit.eccentricity.rawValue)
                            let apoapsis =
                                planet.orbit.semiMajorAxis.astronomicalUnits
                                * (1 + planet.orbit.eccentricity.rawValue)
                            var eccentricSpan = Path()
                            eccentricSpan.move(
                                to: CGPoint(x: orbitPosition(for: periapsis, width: size.width), y: lane)
                            )
                            eccentricSpan.addLine(
                                to: CGPoint(x: orbitPosition(for: apoapsis, width: size.width), y: lane)
                            )
                            context.stroke(
                                eccentricSpan,
                                with: .color(.white.opacity(0.3)),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                            )
                        }
                    }

                    StellarBodySymbol(diameter: 36)
                        .position(x: leadingTrackInset, y: proxy.size.height * 0.47)
                        .accessibilityLabel("Host star at zero astronomical units")

                    ForEach(Array(system.planets.enumerated()), id: \.element.id) { index, planet in
                        planetMarker(for: planet, index: index)
                            .position(
                                x: orbitPosition(
                                    for: planet.orbit.semiMajorAxis.astronomicalUnits,
                                    width: proxy.size.width
                                ),
                                y: planetLaneY(index: index, height: proxy.size.height)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(planetAccessibilityLabel(for: planet, index: index))
                    }
                }
            }
            .frame(height: 280)

            HStack(spacing: 16) {
                Label(rangeLegend, systemImage: "capsule")
                if showsSnowLine {
                    Label("Snow line", systemImage: "snowflake")
                        .foregroundStyle(.cyan)
                }
                Label("Eccentric range", systemImage: "arrow.left.and.right")
                if resolvedMoonCount > 0 {
                    Label("Resolved moons", systemImage: "moon.fill")
                        .foregroundStyle(.indigo)
                }
                Spacer()
                Text(presentation.resolvedPlanetRangeLabel(count: system.planets.count))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    init(system: GeneratedStarSystem, initialScale: StarSystemOrbitScale = .logarithmic) {
        self.system = system
        let diskLowerBound = max(system.protoplanetaryDisk.innerEdge.astronomicalUnits, 0.000_001)
        let diskUpperBound = max(system.protoplanetaryDisk.outerEdge.astronomicalUnits, diskLowerBound * 10)
        orbitRange = StarSystemOrbitRange(
            orbits: system.planets.map(\.orbit),
            fallback: diskLowerBound...diskUpperBound
        )
        _scale = State(initialValue: initialScale)
    }

    private func orbitPosition(for astronomicalUnits: Double, width: Double) -> Double {
        let availableWidth = max(1, width - leadingTrackInset - trailingTrackInset)
        return leadingTrackInset + availableWidth * scale.position(for: astronomicalUnits, in: orbitalRange)
    }

    private func planetLaneY(index: Int, height: Double) -> Double {
        let lanes = [height * 0.25, height * 0.47, height * 0.69]
        return lanes[index % lanes.count]
    }

    private func planetMarker(for planet: GeneratedPlanet, index: Int) -> some View {
        let diameter = symbolDiameter(for: planet.mass)
        return PlanetaryBodySymbol(
            physicalState: planet.physicalState,
            liquidWaterCoverage: planet.environment.liquidWaterCoverage,
            waterIceCoverage: planet.environment.waterIceCoverage,
            diameter: diameter
        )
        .overlay(alignment: .leading) {
            HStack(spacing: moonSpacing) {
                ForEach(planet.moons, id: \.id) { moon in
                    PlanetaryBodySymbol(
                        physicalState: moon.physicalState,
                        liquidWaterCoverage: moon.environment.liquidWaterCoverage,
                        waterIceCoverage: moon.environment.waterIceCoverage,
                        diameter: moonDiameter
                    )
                }
            }
            .fixedSize()
            .offset(x: diameter + 5)
            .accessibilityHidden(true)
        }
        .overlay {
            VStack(spacing: 4) {
                Text("P\(index + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(presentation.number(planet.orbit.semiMajorAxis.astronomicalUnits)) AU")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .offset(y: diameter / 2 + 18)
        }
    }

    private func planetAccessibilityLabel(for planet: GeneratedPlanet, index: Int) -> String {
        let moonDescription = planet.moons.count == 1 ? "1 resolved moon" : "\(planet.moons.count) resolved moons"
        return "Planet \(index + 1), \(presentation.astronomicalUnits(planet.orbit.semiMajorAxis)), \(presentation.earthMasses(planet.mass)), \(moonDescription)"
    }

    private func symbolDiameter(for mass: AstronomicalMass) -> Double {
        min(40, max(15, 17 + log10(max(0.01, mass.earthMasses)) * 6))
    }
}

#Preview("Seed 1 · Linear Orbits") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 1)
    )
    if let system {
        StarSystemOrbitDiagram(system: system, initialScale: .linear)
            .padding()
            .frame(width: 1_280, height: 470)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}

#Preview("Seed 10925987079005406032 · Moon Symbols") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 10_925_987_079_005_406_032)
    )
    if let system {
        StarSystemOrbitDiagram(system: system)
            .padding()
            .frame(width: 1_600, height: 470)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}
