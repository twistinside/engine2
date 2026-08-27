import simd
import SwiftUI

/// Persistent capability-driven inspector for the selected Simulation entity.
///
/// Every displayed value comes through a read-only capability protocol backed
/// by authoritative ECS stores. One focused callback stages the orbit-assist
/// command without granting the view World or advancement authority.
struct SelectedEntityInspector: View {
    let source: any PSelectedEntitySource
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
            Text((entity as? any PDisplayNamed)?.displayName ?? "Entity \(entity.id.index)")
                .font(.title2.weight(.semibold))
            Text("ID \(entity.id.index):\(entity.id.generation)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func inspectorSections(for entity: Entity) -> some View {
        if let selectable = entity as? any PSelectable {
            section("Selection", systemImage: "cursorarrow.rays") {
                metric("State", String(describing: selectable.selectionState))
                if let bounded = entity as? any PSelectionBounded {
                    metric("Hit radius", meters(bounded.selectionRadius))
                }
            }
        }

        if let positioned = entity as? any PPositionable {
            section("Transform", systemImage: "move.3d") {
                metric("Position", vector(positioned.position, unit: "m"))
                if let scalable = entity as? any PScalable {
                    metric("Scale", vector(scalable.scale))
                }
                if let orientable = entity as? any POrientable {
                    metric("Rotation", format(Double(orientable.rotation.angle), unit: "rad"))
                }
            }
        }

        if let movable = entity as? any PMovable {
            section("Motion", systemImage: "location.north.line") {
                metric("Velocity", vector(movable.velocity, unit: "m/s"))
                metric("Speed", format(simd_length(movable.velocity), unit: "m/s"))
                metric("Acceleration", vector(movable.acceleration, unit: "m/s²"))
                velocityGlyph(movable.velocity)
            }
        }

        if let orbiting = entity as? any POrbiting {
            section("Orbital Rail", systemImage: "circle.dashed") {
                metric("Radius", meters(orbiting.orbitalRadius))
                metric("Rail velocity", vector(orbiting.orbitalVelocity, unit: "m/s"))
            }
        }

        if let circularizable = entity as? any POrbitCircularizable {
            section("Orbit Assist", systemImage: "scope") {
                if let estimate = circularizable.orbitCircularizationEstimate {
                    metric("Required Δv", format(estimate.deltaV, unit: "m/s"))
                    metric("Required fuel", kilograms(estimate.requiredFuel))
                    Button {
                        requestOrbitCircularization(entity.id)
                    } label: {
                        Label("Circularize Orbit", systemImage: "circle.dashed")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isAdvancementActive == false
                            || estimate.hasSufficientFuel == false
                    )

                    if isAdvancementActive == false {
                        Text("Resume the simulation to use the orbit assist.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if estimate.hasSufficientFuel == false {
                        Text("The maneuver requires more fuel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Applies one fuel-costed ideal impulse around the designated primary.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No valid circular orbit is available here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if let gravitySource = entity as? any PGravitySource {
            section("Gravity", systemImage: "sun.max") {
                metric("Role", "Source")
                metric("μ", format(gravitySource.gravitationalParameter, unit: "m³/s²"))
            }
        }

        if entity is any PGravityAffected {
            section("Gravity Response", systemImage: "arrow.down.to.line") {
                metric("Role", "Receiver")
            }
        }

        if let massive = entity as? any PLiveMass {
            section("Mass", systemImage: "scalemass") {
                metric("Dry", kilograms(massive.dryMass))
                metric("Current", kilograms(massive.mass))
            }
        }

        if let propelled = entity as? any PPropelled {
            section("Propulsion", systemImage: "flame") {
                metric("Maximum thrust", format(propelled.maximumThrust, unit: "N"))
                metric("Exhaust velocity", format(propelled.exhaustVelocity, unit: "m/s"))
            }
        }

        if let fueled = entity as? any PFueled {
            section("Fuel", systemImage: "fuelpump") {
                metric("Remaining", kilograms(fueled.remainingFuel))
                metric("Capacity", kilograms(fueled.fuelCapacity))
                ProgressView(value: fueled.remainingFuel, total: fueled.fuelCapacity)
                    .tint(.orange)
            }
        }

        if let cargo = entity as? any PCargoCarrying {
            section("Cargo", systemImage: "shippingbox") {
                metric("Ore", kilograms(cargo.cargoOre))
                metric("Capacity", kilograms(cargo.cargoCapacity))
                ProgressView(value: cargo.cargoOre, total: cargo.cargoCapacity)
                    .tint(.cyan)
            }
        }

        if let ore = entity as? any POreContaining {
            section("Ore Deposit", systemImage: "mountain.2") {
                metric("Remaining", kilograms(ore.remainingOre))
            }
        }

        if let mineable = entity as? any PMineable {
            section("Mining", systemImage: "hammer") {
                metric("Range", meters(mineable.interactionRange))
                metric("Rate", format(mineable.miningRate, unit: "kg/s"))
            }
        }

        if let depot = entity as? any PDepotServicing {
            section("Depot Service", systemImage: "building.2") {
                metric("Delivered ore", kilograms(depot.deliveredOre))
                metric("Range", meters(depot.depotInteractionRange))
                metric("Unload rate", format(depot.unloadingRate, unit: "kg/s"))
                metric("Refuel rate", format(depot.refuelingRate, unit: "kg/s"))
            }
        }

        if let controlled = entity as? any PPlayerControlled {
            section("Player Control", systemImage: "gamecontroller") {
                metric("Translation", vector(controlled.translationIntent))
                metric("Interaction", controlled.isInteractionActive ? "Active" : "Idle")
            }
        }

        if let renderable = entity as? any PRenderable {
            section("Rendering", systemImage: "cube") {
                metric("Mesh", String(describing: renderable.meshID))
                metric("Material", String(describing: renderable.materialID))
            }
        }

        if let collidable = entity as? any PCollidable {
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
