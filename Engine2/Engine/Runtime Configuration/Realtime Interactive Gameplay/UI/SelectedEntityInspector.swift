import simd
import SwiftUI

/// Persistent capability-driven inspector for the selected Simulation entity.
///
/// Every displayed value comes through a read-only capability protocol backed
/// by authoritative ECS stores. One focused callback stages the orbit-assist
/// command without granting the view World or advancement authority.
struct SelectedEntityInspector: View {
    let source: any SelectedEntitySource
    let isAdvancementActive: Bool
    let requestOrbitCircularization: (EntityID) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            ScrollView {
                if let entity = source.selectedEntity {
                    VStack(alignment: .leading, spacing: 12) {
                        inspectorHeader(for: entity)
                        inspectorSections(for: entity)
                    }
                    .padding(16)
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "cursorarrow.click",
                        description: Text("Click a body to inspect it.")
                    )
                    .padding(24)
                }
            }
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func inspectorHeader(for entity: Entity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text((entity as? any DisplayNamed)?.displayName ?? "Entity \(entity.id.index)")
                .font(.title2.weight(.semibold))
            Text("ID \(entity.id.index):\(entity.id.generation)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func inspectorSections(for entity: Entity) -> some View {
        if let selectable = entity as? any Selectable {
            section("Selection", systemImage: "cursorarrow.rays") {
                metric("State", String(describing: selectable.selectionState))
                metric("Hit radius", meters(selectable.selectionRadius))
            }
        }

        if let positioned = entity as? any Positionable {
            section("Transform", systemImage: "move.3d") {
                metric("Position", vector(positioned.position, unit: "m"))
                if let scalable = entity as? any Scalable {
                    metric("Scale", vector(scalable.scale))
                }
                if let orientable = entity as? any Orientable {
                    metric("Rotation", format(Double(orientable.rotation.angle), unit: "rad"))
                }
            }
        }

        if let movable = entity as? any Movable {
            section("Motion", systemImage: "location.north.line") {
                metric("Velocity", vector(movable.velocity, unit: "m/s"))
                metric("Speed", format(simd_length(movable.velocity), unit: "m/s"))
                metric("Acceleration", vector(movable.acceleration, unit: "m/s²"))
                velocityGlyph(movable.velocity)
            }
        }

        if let orbiting = entity as? any Orbiting {
            section("Orbital Rail", systemImage: "circle.dashed") {
                metric("Radius", meters(orbiting.orbitalRadius))
                metric("Rail velocity", vector(orbiting.orbitalVelocity, unit: "m/s"))
            }
        }

        if let circularizable = entity as? any OrbitCircularizable {
            section("Orbit Assist", systemImage: "scope") {
                orbitAssist(for: entity.id, circularizable: circularizable)
            }
        }

        if let gravitySource = entity as? any GravitySource {
            section("Gravity", systemImage: "sun.max") {
                metric("Role", "Source")
                metric("μ", format(gravitySource.gravitationalParameter, unit: "m³/s²"))
            }
        }

        if entity is any GravityAffected {
            section("Gravity Response", systemImage: "arrow.down.to.line") {
                metric("Role", "Receiver")
            }
        }

        if let massive = entity as? any LiveMass {
            section("Mass", systemImage: "scalemass") {
                metric("Dry", kilograms(massive.dryMass))
                metric("Current", kilograms(massive.mass))
            }
        }

        if let propelled = entity as? any Propelled {
            section("Propulsion", systemImage: "flame") {
                metric("Maximum thrust", format(propelled.maximumThrust, unit: "N"))
                metric("Exhaust velocity", format(propelled.exhaustVelocity, unit: "m/s"))
            }
        }

        if let fueled = entity as? any Fueled {
            section("Fuel", systemImage: "fuelpump") {
                metric("Remaining", kilograms(fueled.remainingFuel))
                metric("Capacity", kilograms(fueled.fuelCapacity))
                ProgressView(value: fueled.remainingFuel, total: fueled.fuelCapacity)
                    .tint(.orange)
            }
        }

        if let cargo = entity as? any CargoCarrying {
            section("Cargo", systemImage: "shippingbox") {
                metric("Ore", kilograms(cargo.cargoOre))
                metric("Capacity", kilograms(cargo.cargoCapacity))
                ProgressView(value: cargo.cargoOre, total: cargo.cargoCapacity)
                    .tint(.cyan)
            }
        }

        if let ore = entity as? any OreContaining {
            section("Ore Deposit", systemImage: "mountain.2") {
                metric("Remaining", kilograms(ore.remainingOre))
            }
        }

        if let interactable = entity as? any Interactable {
            section("Interaction", systemImage: "hand.tap") {
                metric("Range", meters(interactable.interactionRange))
            }
        }

        if let mineable = entity as? any Mineable {
            section("Mining", systemImage: "hammer") {
                metric("Rate", format(mineable.miningRate, unit: "kg/s"))
            }
        }

        if let depot = entity as? any DepotServicing {
            section("Depot Service", systemImage: "building.2") {
                metric("Delivered ore", kilograms(depot.deliveredOre))
                metric("Unload rate", format(depot.unloadingRate, unit: "kg/s"))
                metric("Refuel rate", format(depot.refuelingRate, unit: "kg/s"))
            }
        }

        if let controlled = entity as? any PlayerControlled {
            section("Player Control", systemImage: "gamecontroller") {
                metric("Translation", vector(controlled.translationIntent))
                metric("Interaction", interactionDescription(controlled.interactionState))
            }
        }

        if let renderable = entity as? any Renderable {
            section("Rendering", systemImage: "cube") {
                metric("Mesh", String(describing: renderable.meshID))
                metric("Material", String(describing: renderable.materialID))
            }
        }

        if let collidable = entity as? any Collidable {
            section("Collision", systemImage: "circle.hexagongrid") {
                metric("Radius", meters(collidable.collisionRadius))
                metric("Restitution", format(collidable.restitution))
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 7) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func orbitAssist(
        for entityID: EntityID,
        circularizable: any OrbitCircularizable
    ) -> some View {
        if let estimate = circularizable.orbitCircularizationEstimate {
            let isActive = circularizable.isOrbitCircularizationActive
            metric("Required Δv", format(estimate.deltaV, unit: "m/s"))
            metric("Available Δv", format(estimate.availableDeltaV, unit: "m/s"))
            metric("Reserve after burn", format(estimate.deltaVMargin, unit: "m/s"))
            ProgressView(value: estimate.deltaVReserveFraction)
                .tint(deltaVReserveColor(for: estimate))
                .accessibilityLabel("Delta-v reserve after maneuver")
                .accessibilityValue(percent(estimate.deltaVReserveFraction))
            metric("Required fuel", kilograms(estimate.requiredFuel))
            metric("Minimum burn", duration(estimate.minimumBurnDuration))

            Button {
                requestOrbitCircularization(entityID)
            } label: {
                orbitAssistButtonLabel(isActive: isActive)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isActive
                    || isAdvancementActive == false
                    || estimate.hasSufficientFuel == false
            )

            orbitAssistStatus(isActive: isActive, estimate: estimate)
        } else {
            Text("No valid circular orbit is available here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func orbitAssistButtonLabel(isActive: Bool) -> some View {
        HStack(spacing: 6) {
            if isActive && isAdvancementActive {
                ProgressView()
                    .controlSize(.small)
            } else if isActive {
                Image(systemName: "pause.circle")
            } else {
                Image(systemName: "circle.dashed")
            }
            Text(
                isActive
                    ? (isAdvancementActive ? "Circularizing" : "Circularization Paused")
                    : "Circularize Orbit"
            )
        }
    }

    @ViewBuilder
    private func orbitAssistStatus(
        isActive: Bool,
        estimate: OrbitCircularizationEstimate
    ) -> some View {
        if isActive {
            Text(
                isAdvancementActive
                    ? "Autopilot has translation control and is applying finite thrust."
                    : "Resume the simulation to continue the autopilot burn."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if isAdvancementActive == false {
            Text("Resume the simulation to use the orbit assist.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if estimate.hasSufficientFuel == false {
            Text("The maneuver needs \(format(-estimate.deltaVMargin, unit: "m/s")) more ideal Δv.")
                .font(.caption)
                .foregroundStyle(.red)
        } else if estimate.deltaVReserveFraction <= 0.05 {
            Text("The maneuver leaves almost no Δv reserve.")
                .font(.caption)
                .foregroundStyle(.red)
        } else if estimate.deltaVReserveFraction <= 0.2 {
            Text("The remaining Δv reserve is getting low.")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        if estimate.minimumBurnOrbitFraction >= 1.0 / 12.0 {
            Text("The minimum burn spans at least 30° of the local orbit; gravity losses may prevent a clean circularization.")
                .font(.caption)
                .foregroundStyle(.red)
        } else if estimate.minimumBurnOrbitFraction >= 1.0 / 36.0 {
            Text("The minimum burn spans at least 10° of the local orbit, so expect noticeable steering losses.")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if isActive == false && isAdvancementActive {
            Text("Autopilot will use bounded thrust until the orbit is circularized.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deltaVReserveColor(for estimate: OrbitCircularizationEstimate) -> Color {
        if estimate.hasSufficientFuel == false || estimate.deltaVReserveFraction <= 0.05 {
            return .red
        }
        if estimate.deltaVReserveFraction <= 0.2 {
            return .orange
        }
        return .green
    }

    private func interactionDescription(_ state: PlayerInteractionState) -> String {
        switch state {
        case .inactive:
            "Idle"
        case .active:
            "Active"
        }
    }

    @ViewBuilder
    private func velocityGlyph(_ velocity: SIMD3<Double>) -> some View {
        let planarVelocity = SIMD2<Double>(velocity.x, velocity.y)
        let speed = simd_length(planarVelocity)
        if speed > 0.0001 {
            HStack {
                Text("Direction")
                Spacer()
                Image(systemName: "arrow.right")
                    .rotationEffect(.radians(atan2(planarVelocity.y, planarVelocity.x)))
                    .foregroundStyle(.cyan)
                Text(format(speed, unit: "m/s"))
                    .font(.caption.monospacedDigit())
            }
            .font(.caption)
        }
    }

    private func vector(_ value: SIMD2<Double>, unit: String? = nil) -> String {
        "(\(format(value.x)), \(format(value.y)))\(unit.map { " \($0)" } ?? "")"
    }

    private func vector(_ value: SIMD3<Double>, unit: String? = nil) -> String {
        "(\(format(value.x)), \(format(value.y)), \(format(value.z)))\(unit.map { " \($0)" } ?? "")"
    }

    private func vector(_ value: SIMD3<Float>, unit: String? = nil) -> String {
        vector(SIMD3<Double>(value), unit: unit)
    }

    private func format(_ value: Double, unit: String? = nil) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        return unit.map { "\(number) \($0)" } ?? number
    }

    private func meters(_ value: Double) -> String {
        format(value, unit: "m")
    }

    private func kilograms(_ value: Double) -> String {
        format(value, unit: "kg")
    }

    private func duration(_ seconds: Double) -> String {
        guard seconds >= 60 else {
            return format(seconds, unit: "s")
        }

        let minutes = Int(seconds / 60)
        let remainingSeconds = seconds - Double(minutes * 60)
        return "\(minutes)m \(format(remainingSeconds))s"
    }

    private func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }
}

#Preview {
    let simulation = SimulationRuntime(
        worldBuilder: MiningWorldBuilder(),
        configuration: .miningGame,
        behavior: MiningSimulationBehavior(),
        inputBaseline: nil
    )
    SelectedEntityInspector(
        source: simulation,
        isAdvancementActive: true,
        requestOrbitCircularization: { _ in }
    )
        .frame(width: 320, height: 720)
}
