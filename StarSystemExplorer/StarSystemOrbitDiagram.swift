import Foundation
import SwiftUI

/// Places resolved planets on a selectable linear or logarithmic axis while keeping body symbols legible.
struct StarSystemOrbitDiagram: View {
    let system: GeneratedStarSystem

    @State private var scale: StarSystemOrbitScale

    private let presentation = StarSystemPresentation()
    private let orbitRange: StarSystemOrbitRange
    private let trackInset = 58.0

    private var orbitalRange: ClosedRange<Double> {
        orbitRange.visibleRange
    }

    private var tickValues: [Double] {
        scale.tickValues(in: orbitalRange)
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

    var body: some View {
        ExplorerCard(
            title: "Orbital Architecture",
            subtitle: subtitle,
            systemImage: "circle.hexagongrid.fill",
            tint: .indigo
        ) {
            Picker("Orbit scale", selection: $scale) {
                ForEach(StarSystemOrbitScale.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 220)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .help("Switch between linear and zero-safe logarithmic orbital distance")

            GeometryReader { proxy in
                ZStack {
                    Canvas { context, size in
                        let midY = size.height * 0.47
                        let trackStart = trackInset
                        let trackEnd = size.width - trackInset * 0.45
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

                        for (index, tick) in tickValues.enumerated() where orbitalRange.contains(tick) {
                            let x = orbitPosition(for: tick, width: size.width)
                            var mark = Path()
                            mark.move(to: CGPoint(x: x, y: midY - 18))
                            mark.addLine(to: CGPoint(x: x, y: midY + 18))
                            context.stroke(mark, with: .color(.white.opacity(0.18)), lineWidth: 1)
                            if index > 0 {
                                let isLastTick = index == tickValues.indices.last
                                let labelAnchor: UnitPoint = isLastTick ? .bottomTrailing : .top
                                let labelY = isLastTick ? midY - 20 : midY + 31
                                context.draw(
                                    Text("\(presentation.number(tick)) AU")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary),
                                    at: CGPoint(x: x, y: labelY),
                                    anchor: labelAnchor
                                )
                            }
                        }

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

                    VStack(spacing: 4) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, .yellow, .orange],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 22
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: .yellow.opacity(0.75), radius: 12)
                        Text("STAR · 0 AU")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                    .position(x: trackInset, y: proxy.size.height * 0.47)

                    ForEach(Array(system.planets.enumerated()), id: \.element.id) { index, planet in
                        VStack(spacing: 4) {
                            PlanetaryBodySymbol(
                                physicalState: planet.physicalState,
                                liquidWaterCoverage: planet.environment.liquidWaterCoverage,
                                waterIceCoverage: planet.environment.waterIceCoverage,
                                diameter: symbolDiameter(for: planet.mass)
                            )
                            Text("P\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(presentation.number(planet.orbit.semiMajorAxis.astronomicalUnits))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .position(
                            x: orbitPosition(
                                for: planet.orbit.semiMajorAxis.astronomicalUnits, width: proxy.size.width),
                            y: planetLaneY(index: index, height: proxy.size.height)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "Planet \(index + 1), \(presentation.astronomicalUnits(planet.orbit.semiMajorAxis)), \(presentation.earthMasses(planet.mass))"
                        )
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
        let availableWidth = max(1, width - trackInset * 1.45)
        return trackInset + availableWidth * scale.position(for: astronomicalUnits, in: orbitalRange)
    }

    private func planetLaneY(index: Int, height: Double) -> Double {
        let lanes = [height * 0.25, height * 0.47, height * 0.69]
        return lanes[index % lanes.count]
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
