import Foundation
import SwiftUI

/// Draws exact planar rail and transfer samples on one top-down physical linear scale.
struct GravitySystemDiagram: View {
    let model: GravitySystemExplorerModel

    private let presentation = GravitySystemPresentation()
    private let canvasPadding: CGFloat = 34

    private var plottedPositions: [PlanarPosition] {
        model.planetRailPositions.values.flatMap { $0 }
            + model.moonRailPositions.values.flatMap { $0 }
            + model.transferPositions
            + model.bodyStates.map(\.state.position)
    }

    private var extentMeters: Double {
        let maximumCoordinate = plottedPositions.reduce(0.0) { currentMaximum, position in
            max(currentMaximum, abs(position.meters.x), abs(position.meters.y))
        }
        let fallback = max(
            model.sourceSystem.star.radius.meters * 12,
            model.sourceSystem.protoplanetaryDisk.outerEdge.meters
        )
        guard maximumCoordinate > 0 else {
            return max(fallback, 1)
        }
        return max(maximumCoordinate * 1.12, model.sourceSystem.star.radius.meters * 12, 1)
    }

    private var subtitle: String {
        "Top-down physical linear scale · exact rail ephemeris at "
            + presentation.elapsedTime(seconds: model.elapsedSeconds)
    }

    private var extentLabel: String {
        "±\(presentation.distance(AstronomicalDistance(meters: extentMeters)))"
    }

    var body: some View {
        ExplorerCard(
            title: "Planar Gravity System",
            subtitle: subtitle,
            systemImage: "circle.grid.cross.fill",
            tint: .cyan,
            accessory: {
                Text(extentLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        ) {
            GeometryReader { proxy in
                let viewport = GravitySystemViewport(
                    size: proxy.size,
                    padding: canvasPadding,
                    extentMeters: extentMeters
                )
                ZStack {
                    Canvas { context, size in
                        let viewport = GravitySystemViewport(
                            size: size,
                            padding: canvasPadding,
                            extentMeters: extentMeters
                        )
                        var horizontalAxis = Path()
                        horizontalAxis.move(to: CGPoint(x: canvasPadding, y: viewport.center.y))
                        horizontalAxis.addLine(
                            to: CGPoint(x: size.width - canvasPadding, y: viewport.center.y)
                        )
                        context.stroke(horizontalAxis, with: .color(.white.opacity(0.08)), lineWidth: 1)

                        var verticalAxis = Path()
                        verticalAxis.move(to: CGPoint(x: viewport.center.x, y: canvasPadding))
                        verticalAxis.addLine(
                            to: CGPoint(x: viewport.center.x, y: size.height - canvasPadding)
                        )
                        context.stroke(verticalAxis, with: .color(.white.opacity(0.08)), lineWidth: 1)

                        for planet in model.sourceSystem.planets {
                            guard let positions = model.planetRailPositions[planet.id] else {
                                continue
                            }
                            context.stroke(
                                path(for: positions, viewport: viewport),
                                with: .color(.white.opacity(0.24)),
                                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                            )
                        }

                        for planet in model.sourceSystem.planets {
                            for moon in planet.moons {
                                guard let positions = model.moonRailPositions[moon.id],
                                      railIsLegible(positions, viewport: viewport) else {
                                    continue
                                }
                                context.stroke(
                                    path(for: positions, viewport: viewport),
                                    with: .color(.indigo.opacity(0.7)),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )
                            }
                        }

                        if !model.transferPositions.isEmpty {
                            context.stroke(
                                path(for: model.transferPositions, viewport: viewport),
                                with: .color(.mint),
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [9, 5])
                            )
                            drawTransferMarker(
                                model.transferPositions.first,
                                label: "departure",
                                color: .cyan,
                                viewport: viewport,
                                context: &context
                            )
                            drawTransferMarker(
                                model.transferPositions.last,
                                label: "arrival",
                                color: .orange,
                                viewport: viewport,
                                context: &context
                            )
                        }
                    }

                    StellarBodySymbol(diameter: 24)
                        .position(viewport.center)
                        .accessibilityLabel("Generated star at the gravity-system origin")

                    ForEach(Array(model.sourceSystem.planets.enumerated()), id: \.element.id) { index, planet in
                        if let state = model.state(for: planet.id) {
                            planetMarker(for: planet, ordinal: index + 1)
                                .position(viewport.point(for: state.position))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    "Planet \(index + 1) at \(presentation.distance(planet.orbit.semiMajorAxis))"
                                )
                        }

                        ForEach(planet.moons, id: \.id) { moon in
                            if let moonState = model.state(for: moon.id),
                               moonIsLegible(moon, parent: planet, viewport: viewport) {
                                PlanetaryBodySymbol(
                                    physicalState: moon.physicalState,
                                    liquidWaterCoverage: moon.environment.liquidWaterCoverage,
                                    waterIceCoverage: moon.environment.waterIceCoverage,
                                    diameter: 7
                                )
                                .position(viewport.point(for: moonState.position))
                                .accessibilityLabel(model.moonLabel(for: moon.id))
                            }
                        }
                    }

                    if model.sourceSystem.planets.isEmpty {
                        ContentUnavailableView {
                            Label("Star-Only Resolved System", systemImage: "sun.max.fill")
                        } description: {
                            Text("The gravity projection is valid, but this seed exposes no resolved planet rails.")
                        }
                        .frame(maxWidth: 420)
                    }
                }
            }
            .frame(minHeight: 520)

            HStack(spacing: 16) {
                Label("Generated eccentric rails", systemImage: "circle")
                Label("Circular-reference transfer", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(.mint)
                Label("Current ephemeris positions", systemImage: "circle.fill")
                Spacer()
                Text("Body sizes are symbolic")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func path(
        for positions: [PlanarPosition],
        viewport: GravitySystemViewport
    ) -> Path {
        var path = Path()
        for (index, position) in positions.enumerated() {
            let point = viewport.point(for: position)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func railIsLegible(
        _ positions: [PlanarPosition],
        viewport: GravitySystemViewport
    ) -> Bool {
        let points = positions.map(viewport.point(for:))
        guard let first = points.first else {
            return false
        }
        let bounds = points.dropFirst().reduce(
            CGRect(x: first.x, y: first.y, width: 0, height: 0)
        ) { bounds, point in
            bounds.union(CGRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        return max(bounds.width, bounds.height) >= 8
    }

    private func moonIsLegible(
        _ moon: GeneratedMoon,
        parent: GeneratedPlanet,
        viewport: GravitySystemViewport
    ) -> Bool {
        guard let moonState = model.state(for: moon.id),
              let parentState = model.state(for: parent.id) else {
            return false
        }
        let moonPoint = viewport.point(for: moonState.position)
        let parentPoint = viewport.point(for: parentState.position)
        return hypot(moonPoint.x - parentPoint.x, moonPoint.y - parentPoint.y) >= 5
    }

    private func planetMarker(for planet: GeneratedPlanet, ordinal: Int) -> some View {
        let diameter = min(30, max(12, 15 + log10(max(0.01, planet.mass.earthMasses)) * 4))
        return PlanetaryBodySymbol(
            physicalState: planet.physicalState,
            liquidWaterCoverage: planet.environment.liquidWaterCoverage,
            waterIceCoverage: planet.environment.waterIceCoverage,
            diameter: diameter
        )
        .overlay {
            if let tint = selectionTint(for: planet.id) {
                Circle()
                    .stroke(tint, lineWidth: 2)
                    .padding(-5)
            }
        }
        .overlay(alignment: .top) {
            Text("P\(ordinal)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize()
                .offset(y: -diameter / 2 - 14)
        }
    }

    private func selectionTint(for bodyID: GeneratedBodyID) -> Color? {
        if bodyID == model.selectedSourceID {
            return .cyan
        }
        if bodyID == model.selectedDestinationID {
            return .orange
        }
        return nil
    }

    private func drawTransferMarker(
        _ position: PlanarPosition?,
        label: String,
        color: Color,
        viewport: GravitySystemViewport,
        context: inout GraphicsContext
    ) {
        guard let position else {
            return
        }
        let point = viewport.point(for: position)
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
            with: .color(color)
        )
        context.draw(
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color),
            at: CGPoint(x: point.x + 7, y: point.y - 7),
            anchor: .bottomLeading
        )
    }
}
