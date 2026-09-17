/// Authoritative world-space position for one entity.
///
/// The value is stored in `World.components[PositionComponent.self]`; positioned entity
/// facades read this row live, and simulation systems mutate the store directly.
/// Coordinates use double-precision meters.
struct PositionComponent: Component {
    var position: SIMD3<Double>
}

extension PositionComponent {
    @MainActor init?(for entity: Entity, from state: Entity.InitialState) {
        precondition(state.position == nil || entity is Positionable,
                     "Initial state.position requires Positionable conformance")
        guard entity is Positionable else { return nil }
        if entity is Orbiting {
            guard let rail = entity.world.components[OrbitalRailComponent.self][entity.id],
                  let primaryPosition = entity.world.components[PositionComponent.self][rail.primaryEntityID]?.position else {
                preconditionFailure("An orbiting entity requires its initialized rail and registered primary.")
            }
            self.init(position: rail.state(relativeTo: primaryPosition).position)
        } else {
            self.init(position: state.position ?? .zero)
        }
    }
}
