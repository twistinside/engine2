import SwiftUI

/// Presents deterministic rail ephemerides, gravity context, and one circular-reference transfer comparison.
struct GravitySystemDashboard: View {
    @State private var model: GravitySystemExplorerModel

    private let gravityPresentation = GravitySystemPresentation()
    private let starSystemPresentation = StarSystemPresentation()

    private var moonCount: Int {
        model.sourceSystem.planets.reduce(0) { $0 + $1.moons.count }
    }

    private var gravityAtSourceLabel: String {
        guard let acceleration = model.selectedGravityAccelerationMetersPerSecondSquared else {
            return "—"
        }
        return gravityPresentation.acceleration(metersPerSecondSquared: acceleration)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch model.projectionState {
                case .ready(let gravitySystem):
                    dynamicsOverview(for: gravitySystem)

                    ExplorerCard(
                        title: "Dynamics Controls",
                        subtitle: "Scrub immutable rails and choose one reference transfer",
                        systemImage: "slider.horizontal.3",
                        tint: .blue
                    ) {
                        GravitySystemControls(model: model)
                    }

                    GravitySystemDiagram(model: model)
                    transferSummary

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text(
                            "Gravity projection validation passed for seed \(gravitySystem.seed.rawValue). "
                                + "Every displayed body position comes from the shared deterministic ephemeris."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Gravity Projection Failed", systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(message)
                    }
                    .padding(48)
                    .frame(maxWidth: .infinity, minHeight: 440)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(22)
        }
        .scrollIndicators(.visible)
    }

    @ViewBuilder private var transferSummary: some View {
        ExplorerCard(
            title: "Circular-Reference Hohmann Plan",
            subtitle: transferSubtitle,
            systemImage: "arrow.triangle.swap",
            tint: .orange
        ) {
            Label {
                Text(
                    "Circular reference only. The planner uses each planet’s semimajor axis as a circular orbit. "
                        + "It does not claim rendezvous with the generated eccentric rails "
                        + "or predict spacecraft execution."
                )
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.orange.opacity(0.45), lineWidth: 1)
            }

            switch model.transferState {
            case .ready(let plan):
                EagerAdaptiveGrid(minimumColumnWidth: 190, horizontalSpacing: 10, verticalSpacing: 10) {
                    MetricTile(
                        "Departure window",
                        value: gravityPresentation.elapsedTime(seconds: plan.nextWindowWait.seconds),
                        detail: "Departure at \(gravityPresentation.epoch(plan.departureEpoch))",
                        systemImage: "calendar.badge.clock",
                        tint: .cyan
                    )
                    MetricTile(
                        "Transfer time",
                        value: gravityPresentation.elapsedTime(seconds: plan.transferDuration.seconds),
                        detail: "Arrival at \(gravityPresentation.epoch(plan.arrivalEpoch))",
                        systemImage: "hourglass",
                        tint: .mint
                    )
                    MetricTile(
                        "Departure delta-v",
                        value: gravityPresentation.deltaV(metersPerSecond: plan.departureDeltaVMetersPerSecond),
                        detail: model.planetLabel(for: plan.sourceBodyID),
                        systemImage: "flame.fill",
                        tint: .cyan
                    )
                    MetricTile(
                        "Arrival match",
                        value: gravityPresentation.deltaV(metersPerSecond: plan.arrivalDeltaVMetersPerSecond),
                        detail: "Circular destination reference",
                        systemImage: "arrow.down.circle.fill",
                        tint: .orange
                    )
                    MetricTile(
                        "Total delta-v",
                        value: gravityPresentation.deltaV(metersPerSecond: plan.totalDeltaVMetersPerSecond),
                        detail: "Two ideal impulsive burns",
                        systemImage: "sum",
                        tint: .purple
                    )
                    MetricTile(
                        "Required phase",
                        value: gravityPresentation.angle(radians: plan.requiredPhaseAngleRadians),
                        detail: "Destination − source reference",
                        systemImage: "angle",
                        tint: .indigo
                    )
                }
            case .noPlanets:
                transferUnavailable(
                    title: "No Planet Pair",
                    description: "This valid generated system exposes no resolved planets for a transfer comparison."
                )
            case .onePlanet(let bodyID):
                transferUnavailable(
                    title: "One Resolved Planet",
                    description: "\(model.planetLabel(for: bodyID)) has no second resolved planet to connect."
                )
            case .selectionIncomplete:
                transferUnavailable(
                    title: "Select Two Planets",
                    description: "Choose distinct departure and destination planets to form a reference plan."
                )
            case .failed(let message):
                transferUnavailable(title: "Transfer Unavailable", description: message)
            }
        }
    }

    private var transferSubtitle: String {
        guard let source = model.selectedSourceID,
              let destination = model.selectedDestinationID else {
            return "Two-impulse reference planning around the generated star"
        }
        return "\(model.planetLabel(for: source)) → \(model.planetLabel(for: destination))"
    }

    init(system: GeneratedStarSystem) {
        _model = State(initialValue: GravitySystemExplorerModel(system: system))
    }

    private func dynamicsOverview(for gravitySystem: GeneratedGravitySystem) -> some View {
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
                    "Displayed epoch",
                    value: gravityPresentation.epoch(model.currentEpoch),
                    detail: "Reference-relative elapsed time",
                    systemImage: "clock.fill",
                    tint: .blue
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
                MetricTile(
                    "External gravity",
                    value: gravityAtSourceLabel,
                    detail: model.selectedSourceID.map { "At \(model.planetLabel(for: $0)); source excluded" }
                        ?? "No selected source planet",
                    systemImage: "arrow.down.to.line.compact",
                    tint: .orange
                )
            }
        }
    }

    private func transferUnavailable(title: String, description: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "point.2.filled.connected.trianglepath.dotted")
        } description: {
            Text(description)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Dynamics · Seed 1") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 1)
    )
    if let system {
        GravitySystemDashboard(system: system)
            .frame(width: 1_280, height: 900)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}

#Preview("Dynamics · Seed 43 · No Planets") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 43)
    )
    if let system {
        GravitySystemDashboard(system: system)
            .frame(width: 1_280, height: 900)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}

#Preview("Dynamics · Seed 67 · One Planet") {
    let system = try? StarSystemGenerator(policy: .coreAccretionLiteV1).generate(
        seed: StarSystemSeed(rawValue: 67)
    )
    if let system {
        GravitySystemDashboard(system: system)
            .frame(width: 1_280, height: 900)
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .preferredColorScheme(.dark)
    }
}
