import Foundation
import SwiftUI

/// Draws exact planar rail and transfer samples on one top-down physical linear scale.
struct GravitySystemDiagram: View {
    let model: GravitySystemExplorerModel

    @State private var zoomScale = 1.0

    private let presentation = GravitySystemPresentation()
    private let canvasPadding: CGFloat = 34

    private var subtitle: String {
        "Top-down physical linear scale · body positions at "
            + presentation.elapsedTime(seconds: model.elapsedSeconds)
    }

    private var zoomScaleLabel: String {
        zoomScale.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    private var planetRails: [[PlanarPosition]] {
        model.sourceSystem.planets.compactMap { planet in
            model.planetRailPositions[planet.id]
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 10) {
            Label("System scale", systemImage: "magnifyingglass")
                .font(.subheadline.weight(.semibold))

            Button("Zoom out", systemImage: "minus.magnifyingglass") {
                adjustZoom(by: -0.25)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(zoomScale <= GravitySystemViewport.supportedZoomScaleRange.lowerBound)

            Slider(
                value: $zoomScale,
                in: GravitySystemViewport.supportedZoomScaleRange,
                step: 0.25
            ) {
                Text("System scale")
            }
            .labelsHidden()
            .accessibilityValue(zoomScaleLabel)
            .frame(maxWidth: 280)
            .help("Magnify the physical system view around the generated star")

            Button("Zoom in", systemImage: "plus.magnifyingglass") {
                adjustZoom(by: 0.25)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(zoomScale >= GravitySystemViewport.supportedZoomScaleRange.upperBound)

            Text(zoomScaleLabel)
                .font(.caption.monospacedDigit().weight(.semibold))
                .frame(width: 46, alignment: .trailing)
                .accessibilityHidden(true)

            Button("Fit") {
                zoomScale = 1
            }
            .buttonStyle(.bordered)
            .disabled(zoomScale == 1)

            Spacer()
        }
    }

    private var diagramPlot: some View {
        GeometryReader { proxy in
            diagramContent(
                in: GravitySystemViewport(
                    size: proxy.size,
                    padding: canvasPadding,
                    extentMeters: model.diagramExtentMeters,
                    zoomScale: zoomScale
                )
            )
        }
        .frame(minHeight: 520)
    }

    private var diagramLegend: some View {
        HStack(spacing: 16) {
            Label("Generated eccentric rails", systemImage: "circle")
            Label("Circular-reference transfer", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                .foregroundStyle(.mint)
            Label("Reference transfer vehicle", systemImage: "paperplane.fill")
                .foregroundStyle(.pink)
            Label("Current ephemeris positions", systemImage: "circle.fill")
            Text("D departure · A destination")
                .font(.caption.monospaced())
            Spacer()
            Text("Body sizes are symbolic")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        ExplorerCard(
            title: "Planar Gravity System",
            subtitle: subtitle,
            systemImage: "circle.grid.cross.fill",
            tint: .cyan,
            accessory: {
                Text(zoomScaleLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        ) {
            zoomControls
            diagramPlot
            diagramLegend
        }
    }

    private func diagramContent(in viewport: GravitySystemViewport) -> some View {
        ZStack(alignment: .topTrailing) {
            GravitySystemStaticRailLayer(
                viewport: viewport,
                planetRails: planetRails,
                transferPositions: model.transferPositions
            )
            .equatable()

            moonRailLayer(in: viewport)

            StellarBodySymbol(diameter: 24)
                .position(viewport.center)
                .accessibilityLabel("Generated star at the gravity-system origin")

            bodySymbols(in: viewport)
            transferVehicle(in: viewport)
            emptySystemPlaceholder()

            Text(visibleSpanLabel(for: viewport))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.48), in: Capsule())
                .padding(10)
        }
        .clipped()
    }

    private func moonRailLayer(in viewport: GravitySystemViewport) -> some View {
        Canvas { context, _ in
            for planet in model.sourceSystem.planets {
                guard let parentState = model.state(for: planet.id) else {
                    continue
                }
                for moon in planet.moons {
                    guard let positions = model.moonRelativeRailPositions[moon.id],
                          railIsLegible(positions, in: viewport) else {
                        continue
                    }
                    context.stroke(
                        path(
                            for: positions,
                            translatedBy: parentState.position,
                            in: viewport
                        ),
                        with: .color(.indigo.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func bodySymbols(in viewport: GravitySystemViewport) -> some View {
        ForEach(model.sourceSystem.planets.indices, id: \.self) { index in
            let planet = model.sourceSystem.planets[index]
            if let state = model.state(for: planet.id),
               viewport.contains(state.position) {
                planetMarker(for: planet, ordinal: index + 1)
                    .position(viewport.point(for: state.position))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(planetAccessibilityLabel(for: planet, ordinal: index + 1))
            }

            ForEach(planet.moons, id: \.id) { moon in
                if let moonState = model.state(for: moon.id),
                   viewport.contains(moonState.position),
                   moonIsLegible(moon, parent: planet, in: viewport) {
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
    }

    @ViewBuilder private func transferVehicle(in viewport: GravitySystemViewport) -> some View {
        if let vehicleState = model.transferVehicleState,
           viewport.contains(vehicleState.position) {
            GravityTransferVehicleSymbol(status: vehicleState.status)
                .overlay {
                    Text(vehicleLabel(for: vehicleState.status))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.72), in: Capsule())
                        .fixedSize()
                        .offset(x: 54, y: -20)
                        .accessibilityHidden(true)
                }
                .position(viewport.point(for: vehicleState.position))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Reference transfer vehicle, \(vehicleLabel(for: vehicleState.status))")
        }
    }

    @ViewBuilder private func emptySystemPlaceholder() -> some View {
        if model.sourceSystem.planets.isEmpty {
            ContentUnavailableView {
                Label("Star-Only Resolved System", systemImage: "sun.max.fill")
            } description: {
                Text("The gravity projection is valid, but this seed exposes no resolved planet rails.")
            }
            .frame(maxWidth: 420)
        }
    }

    private func path(
        for positions: [PlanarPosition],
        translatedBy translation: PlanarPosition,
        in viewport: GravitySystemViewport
    ) -> Path {
        var path = Path()
        for (index, position) in positions.enumerated() {
            let point = viewport.point(for: translation.adding(position))
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
        in viewport: GravitySystemViewport
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
        in viewport: GravitySystemViewport
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
        .overlay(alignment: .bottomTrailing) {
            selectionBadge(for: planet.id)
                .offset(x: 8, y: 8)
        }
    }

    @ViewBuilder private func selectionBadge(for bodyID: GeneratedBodyID) -> some View {
        if bodyID == model.selectedSourceID {
            Text("D")
                .font(.caption2.monospaced().weight(.heavy))
                .foregroundStyle(.black)
                .frame(width: 17, height: 17)
                .background(.cyan, in: Circle())
                .accessibilityHidden(true)
        } else if bodyID == model.selectedDestinationID {
            Text("A")
                .font(.caption2.monospaced().weight(.heavy))
                .foregroundStyle(.black)
                .frame(width: 17, height: 17)
                .background(.orange, in: Circle())
                .accessibilityHidden(true)
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

    private func planetAccessibilityLabel(for planet: GeneratedPlanet, ordinal: Int) -> String {
        var label = "Planet \(ordinal) at \(presentation.distance(planet.orbit.semiMajorAxis))"
        if planet.id == model.selectedSourceID {
            label += ", selected departure planet"
        } else if planet.id == model.selectedDestinationID {
            label += ", selected destination planet"
        }
        return label
    }

    private func visibleSpanLabel(for viewport: GravitySystemViewport) -> String {
        let horizontalSpan = presentation.distance(
            AstronomicalDistance(meters: viewport.visibleHorizontalHalfSpanMeters)
        )
        let verticalSpan = presentation.distance(
            AstronomicalDistance(meters: viewport.visibleVerticalHalfSpanMeters)
        )
        return "Visible from origin · X ±\(horizontalSpan) · Y ±\(verticalSpan)"
    }

    private func adjustZoom(by increment: Double) {
        zoomScale = min(
            max(
                zoomScale + increment,
                GravitySystemViewport.supportedZoomScaleRange.lowerBound
            ),
            GravitySystemViewport.supportedZoomScaleRange.upperBound
        )
    }

    private func vehicleLabel(for status: GravityTransferVehicleStatus) -> String {
        switch status {
        case .awaitingDeparture:
            "awaiting departure"
        case .inFlight:
            "in flight"
        case .atArrivalReference:
            "at the arrival reference"
        }
    }
}
